{
  config,
  lib,
  pkgs,
  secretFiles,
  username,
  ...
}: let
  stateDir = "/var/lib/mihomo";
  runDir = "/run/mihomo";
  base = import ./mihomo/base.nix {dashboard = pkgs.metacubexd;};
  baseFile = pkgs.writeText "mihomo-base.json" (builtins.toJSON base);
  renderer = ./mihomo/render.py;
  seeds = import ./mihomo/rulesets.nix {inherit pkgs;};
  # Public encryption subkey of the YubiKey. Encrypting needs only this file;
  # decrypting needs the card (PIN and touch), see mihomo-unlock below.
  yubikeyPub = ./mihomo/yubikey.pub;
  # Only proxy inputs live in hosts/nixos.yaml; the host key decrypts them during
  # activation into /run/secrets (tmpfs). glom.yaml stays YubiKey-only.
  secret = {
    sopsFile = secretFiles.hosts.nixos;
    restartUnits = ["mihomo.service"];
  };
  path = name: config.sops.secrets.${name}.path;
  # VLESS+REALITY inputs: one sops secret per field, vless.<region>.<field> in nixos-secrets.
  vlessRegions = ["hk" "sg"];
  vlessFields = ["host" "port" "uuid" "public_key" "short_id" "sni"];
  vlessEntries = lib.concatMap (region: map (field: {inherit region field;}) vlessFields) vlessRegions;
  vlessSecretName = region: field: "vless/${region}/${field}";
  # Credential and argument names use dashes: vless-hk-public-key.
  vlessCredential = region: field: "vless-${region}-${builtins.replaceStrings ["_"] ["-"] field}";
  vlessLoadCredential = map ({
    region,
    field,
  }: "${vlessCredential region field}:${path (vlessSecretName region field)}")
  vlessEntries;
  vlessArgs = lib.concatMapStringsSep " " ({
    region,
    field,
  }: "--${vlessCredential region field}-file %d/${vlessCredential region field}")
  vlessEntries;
  # Decrypts the node cache with the YubiKey into tmpfs, so the next start can use it
  # while the subscription is unreachable. Plaintext never touches the disk.
  unlockCache = pkgs.writeShellApplication {
    name = "mihomo-unlock";
    runtimeInputs = [pkgs.gnupg pkgs.coreutils];
    text = ''
      sudo install -d -m 0700 -o mihomo -g mihomo ${runDir}
      sudo cat ${stateDir}/nodes.gpg | gpg --decrypt \
        | sudo install -m 0600 -o mihomo -g mihomo /dev/stdin ${runDir}/unlocked-nodes.json
      echo "unlocked: run 'systemctl restart mihomo' to start from the cache"
    '';
  };
  # systemd-resolved sticks to whichever link answered last, so names could drift
  # to the LAN router, which returns no records for AI domains. While mihomo runs,
  # make the TUN DNS preferred for every name. The link and this setting both vanish
  # when the TUN goes away, so DNS returns to the LAN. Failures are ignored, so they
  # never stop mihomo.
  tunDns = pkgs.writeShellScript "mihomo-tun-dns" ''
    for _ in $(seq 100); do
      ${pkgs.iproute2}/bin/ip link show mihomo0 >/dev/null 2>&1 && break
      sleep 0.1
    done
    ${pkgs.systemd}/bin/resolvectl dns mihomo0 172.19.0.2 || true
    ${pkgs.systemd}/bin/resolvectl domain mihomo0 '~.' || true
  '';
in {
  environment.systemPackages = [unlockCache];
  # mihomo runs as its own system user, not root. The UID is pinned for the kill
  # switch, which exempts it by UID.
  users.users.mihomo = {
    uid = 982;
    group = "mihomo";
    isSystemUser = true;
    home = stateDir;
  };
  users.groups.mihomo = {};

  # Kill switch: while mihomo is stopped or crashed, host egress is rejected
  # except loopback, the TUN, tailnet, LAN/multicast, the mihomo user (its own
  # dialers), and root (tailscaled, nix-daemon). The exemption is by UID, not
  # cgroup: a cgroup path does not exist until its unit starts, and a missing path
  # would make the whole nftables ruleset fail to load at boot.
  networking.nftables.tables.mihomo-killswitch = {
    family = "inet";
    content = ''
      chain output {
        type filter hook output priority filter; policy accept;
        oifname { "lo", "mihomo0", "tailscale0" } accept
        meta skuid 0 accept
        meta skuid ${toString config.users.users.mihomo.uid} accept
        ip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16, 100.64.0.0/10, 224.0.0.0/4, 255.255.255.255 } accept
        ip6 daddr { fc00::/7, fe80::/10, ff00::/8 } accept
        reject with icmpx type admin-prohibited
      }
    '';
  };

  sops.secrets =
    {"v2raya/subscription" = secret;}
    // builtins.listToAttrs (map ({
        region,
        field,
      }: {
        name = vlessSecretName region field;
        value = secret;
      })
      vlessEntries);

  # Rule lists live in the state directory. Each seed is copied only when its file is
  # missing, so mihomo's own updates are never overwritten.
  systemd.tmpfiles.rules =
    ["d ${stateDir}/ruleset 0750 mihomo mihomo -"]
    ++ lib.mapAttrsToList (name: seed: "C ${stateDir}/ruleset/${name}.list 0644 mihomo mihomo - ${seed}") seeds;

  systemd.services.mihomo = {
    description = "mihomo proxy";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target"];
    # The dashboard lives in the Nix store, outside the home directory, so mihomo
    # serves it only through SAFE_PATHS.
    environment.SAFE_PATHS = "${pkgs.metacubexd}";
    # Keep retrying at boot until the subscription is reachable; never give up.
    startLimitIntervalSec = 0;
    serviceConfig = {
      User = "mihomo";
      Group = "mihomo";
      LoadCredential = ["subscription:${path "v2raya/subscription"}"] ++ vlessLoadCredential;
      ExecStartPre = [
        "${pkgs.python3}/bin/python3 ${renderer} --base ${baseFile} --subscription-file %d/subscription ${vlessArgs} --clash-secret-file ${stateDir}/clash-secret --cache-file ${stateDir}/nodes.gpg --unlocked-file ${runDir}/unlocked-nodes.json --gpg ${pkgs.gnupg}/bin/gpg --gpg-home ${runDir}/gnupg --gpg-keyring ${yubikeyPub} --gpg-recipient 33563CF7FB3FA0495B923B61267A09581BF0FA83 --output ${runDir}/config.json"
        "${lib.getExe pkgs.mihomo} -t -d ${stateDir} -f ${runDir}/config.json"
      ];
      ExecStart = "${lib.getExe pkgs.mihomo} -d ${stateDir} -f ${runDir}/config.json";
      # Runs as root ("+") after start, once the TUN exists.
      ExecStartPost = ["+${tunDns}"];
      StateDirectory = "mihomo";
      StateDirectoryMode = "0700";
      # Keep the last rendered configuration across restarts (tmpfs, cleared at reboot).
      RuntimeDirectory = "mihomo";
      RuntimeDirectoryMode = "0700";
      RuntimeDirectoryPreserve = "yes";
      # The TUN and its routes need CAP_NET_ADMIN; nothing else is required.
      AmbientCapabilities = ["CAP_NET_ADMIN"];
      CapabilityBoundingSet = ["CAP_NET_ADMIN"];
      Restart = "on-failure";
      RestartSec = "30s";
      UMask = "0077";
      LimitCORE = 0;
    };
  };

  # Permit this local user to control only the proxy service.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id === "org.freedesktop.systemd1.manage-units"
          && subject.user === ${builtins.toJSON username}
          && subject.active && subject.local
          && typeof action.lookup === "function"
          && action.lookup("unit") === "mihomo.service"
          && ["start", "stop", "restart"].indexOf(action.lookup("verb")) !== -1) {
        return polkit.Result.YES;
      }
    });
  '';
}
