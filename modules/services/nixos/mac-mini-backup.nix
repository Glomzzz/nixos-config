{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  cfg = config.services.mac-mini-backup;
  credentialRoot = "/var/lib/nixos-backup";
  credentials = [
    "password:${credentialRoot}/password"
    "ssh-key:${credentialRoot}/ssh-key"
    "known-hosts:${credentialRoot}/known-hosts"
  ];
  repository = "sftp:${username}@mac-mini:/Users/${username}/Backups/nixos-restic";
  home = config.users.users.${username}.home;
  ssh = pkgs.writeShellApplication {
    name = "restic-mac-mini-ssh";
    text = ''
      directory="''${CREDENTIALS_DIRECTORY:?systemd credentials are required}"
      exec ${pkgs.openssh}/bin/ssh -F /dev/null \
        -o BatchMode=yes -o IdentitiesOnly=yes -o IdentityAgent=none \
        -o StrictHostKeyChecking=yes -o GlobalKnownHostsFile=/dev/null \
        -o "UserKnownHostsFile=$directory/known-hosts" \
        -o ConnectTimeout=15 -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
        -o "ProxyCommand=${pkgs.ssh-proxy-mac-mini} 22 mac-mini" \
        -i "$directory/ssh-key" -s ${username}@mac-mini sftp
    '';
  };
  sftpOption = "sftp.command=${ssh}/bin/restic-mac-mini-ssh";
  restic = pkgs.writeShellApplication {
    name = "restic-mac-mini";
    text = ''
      export RESTIC_PASSWORD_FILE="''${CREDENTIALS_DIRECTORY:?systemd credentials are required}/password"
      export RESTIC_REPOSITORY=${lib.escapeShellArg repository}
      exec ${pkgs.restic}/bin/restic --option ${lib.escapeShellArg sftpOption} "$@"
    '';
  };
  maintenance = pkgs.writeShellApplication {
    name = "nixos-backup";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      if [[ $(id -u) != 0 ]]; then
        printf '%s\n' 'Run with sudo; private backup credentials are loaded by systemd.' >&2
        exit 1
      fi
      if [[ $# == 0 ]]; then
        printf '%s\n' 'usage: sudo nixos-backup RESTIC_SUBCOMMAND [ARGS...]' >&2
        exit 2
      fi
      exec ${pkgs.systemd}/bin/systemd-run --wait --pipe --collect \
        --unit=nixos-backup-maintenance --uid=${username} \
        ${lib.concatMapStringsSep " \\\n        " (credential: "--property=${lib.escapeShellArg "LoadCredential=${credential}"}") credentials} \
        --property=CacheDirectory=restic-backups-mac-mini \
        --property=CacheDirectoryMode=0700 \
        ${restic}/bin/restic-mac-mini "$@"
    '';
  };
in {
  options.services.mac-mini-backup.enable = lib.mkEnableOption "daily Mac mini backups after provisioning and restore verification";

  config = {
    # Keep the manual service available before scheduling. No credentials,
    # repository initialization, or remote writes happen during activation.
    services.restic.backups.mac-mini = {
      inherit repository;
      user = username;
      passwordFile = "%d/password";
      paths = [home];
      exclude = [
        "${home}/.cache"
        "${home}/.local/share/Trash"
        "${home}/.local/share/Steam/steamapps"
        "${home}/mnt"
      ];
      extraBackupArgs = ["--one-file-system" "--exclude-caches" "--tag home"];
      extraOptions = [sftpOption];
      initialize = false;
      createWrapper = false;
      pruneOpts = ["--keep-daily 7" "--keep-weekly 4" "--keep-monthly 12"];
      runCheck = true;
      # The upstream module embeds this directly in ExecStart; systemd needs
      # %% to pass a literal percent to Restic (a fresh random subset each run).
      checkOpts = ["--read-data-subset=5%%"];
      timerConfig =
        if cfg.enable
        then {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "1h";
        }
        else null;
    };

    environment.systemPackages = [maintenance];
    systemd = {
      tmpfiles.rules = ["d ${credentialRoot} 0700 root root -"];
      services.restic-backups-mac-mini = {
        onFailure = ["maintenance-alert@%n.service"];
        serviceConfig = {
          LoadCredential = credentials;
          UMask = "0077";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = "read-only";
        };
      };
    };
  };
}
