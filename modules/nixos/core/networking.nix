{
  lib,
  pkgs,
  ...
}: let
  # Approved current home connections, not every interface with an RFC1918 IP.
  homeProfiles = [
    "77cdd16f-65e8-4dec-80cc-72ceb2b1700b" # home Wi-Fi 2.4 GHz: sudo connect-me
    "da787781-5e46-43f9-b083-cea4b5f48533" # home Wi-Fi 5 GHz: sudo connect-me_5G
    "72d3039f-b16e-3e34-8f8c-450eea674357" # Wired connection 1 (home adapter)
  ];
  sync = pkgs.writeShellApplication {
    name = "sync-home-firewall";
    runtimeInputs = [pkgs.util-linux];
    text = ''
      # Serialize dispatcher/timer/reload reconciliation without changing any
      # other firewall table. A transaction flushes and replaces only this set.
      exec 9>/run/lock/nixos-home-firewall.lock
      flock 9
      exec ${pkgs.python3}/bin/python3 ${../../../scripts/sync-home-firewall.py} \
        --nmcli ${pkgs.networkmanager}/bin/nmcli --nft ${pkgs.nftables}/bin/nft \
        ${lib.concatMapStringsSep " " (uuid: "--profile ${uuid}") homeProfiles} "$@"
    '';
  };
  dispatcher = pkgs.writeShellScript "home-firewall-dispatcher" ''
    case "$2" in
      pre-down|down)
        exec ${sync}/bin/sync-home-firewall --exclude-interface "$1"
        ;;
      up|dhcp4-change|dhcp6-change|reapply|connectivity-change)
        exec ${sync}/bin/sync-home-firewall
        ;;
    esac
  '';
in {
  networking = {
    networkmanager = {
      enable = true;
      dispatcherScripts = [
        {source = dispatcher;}
        {
          source = dispatcher;
          type = "pre-down";
        }
      ];
    };
    nftables = {
      enable = true;
      tables.nixos-fw.content = ''
        set home-lan-interfaces {
          type ifname
          comment "Active explicitly approved NetworkManager home profiles"
        }
      '';
    };
    firewall = {
      enable = true;
      backend = "nftables";
      checkReversePath = "loose";

      # Module port openings must not apply on arbitrary laptop networks.
      allowedTCPPorts = lib.mkForce [];
      allowedTCPPortRanges = lib.mkForce [];
      allowedUDPPorts = lib.mkForce [];
      allowedUDPPortRanges = lib.mkForce [];
    };

    # Preserve DHCP, VPN, and split-DNS data instead of fixed public resolvers.
    nameservers = [];
  };

  services.resolved.enable = true;

  systemd = {
    services.home-firewall-sync = {
      description = "Reconcile approved home-LAN firewall interfaces";
      wants = ["NetworkManager.service"];
      after = ["NetworkManager.service" "nftables.service"];
      wantedBy = ["multi-user.target"];
      onFailure = ["maintenance-alert@%n.service"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${sync}/bin/sync-home-firewall";
      };
    };
    # Reload starts with an empty set. Reconcile afterward (or on the fallback
    # timer), never persist an old interface approval through a ruleset reload.
    services.nftables.serviceConfig.ExecReload = lib.mkAfter [
      "${pkgs.systemd}/bin/systemctl --no-block start home-firewall-sync.service"
    ];
    timers.home-firewall-sync = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitActiveSec = "1min";
      };
    };
  };
}
