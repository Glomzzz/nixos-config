{
  config,
  lib,
  pkgs,
  ...
}: let
  mountPoint = "${config.home.homeDirectory}/mnt/mac-mini";
  credentials = "/run/secrets/rendered/smb-mac-mini-credentials";

  macMiniSmbMount = pkgs.writeShellApplication {
    name = "mac-mini-smb-mount";
    runtimeInputs = with pkgs; [
      coreutils
      iproute2
      libressl.nc
      gnused
      rclone
      util-linux
    ];
    text = ''
      mount_point=${lib.escapeShellArg mountPoint}
      credentials=${lib.escapeShellArg credentials}

      mkdir -p "$mount_point"

      if mountpoint -q -- "$mount_point"; then
        mount_type=$(findmnt -rn -o FSTYPE --target "$mount_point")
        if [ "$mount_type" != "fuse.rclone" ]; then
          printf 'mac-mini-smb-mount: refusing to replace %s at %s\n' \
            "$mount_type" "$mount_point" >&2
          exit 1
        fi
        /run/wrappers/bin/fusermount3 -u -z "$mount_point"
      fi

      if [ ! -r "$credentials" ]; then
        printf 'mac-mini-smb-mount: credentials are not readable: %s\n' \
          "$credentials" >&2
        exit 1
      fi

      username=$(sed -n 's/^username=//p' "$credentials")
      password=$(sed -n 's/^password=//p' "$credentials")
      if [ -z "$username" ] || [ -z "$password" ]; then
        printf 'mac-mini-smb-mount: incomplete credentials in %s\n' \
          "$credentials" >&2
        exit 1
      fi

      lan_ip=192.168.50.198
      smb_host=mac-mini
      lan_route=$(ip -4 route get "$lan_ip" 2>/dev/null || true)
      if [ -n "$lan_route" ] && \
        [[ "$lan_route" != *" via "* ]] && \
        [[ "$lan_route" != *" dev tailscale0 "* ]] && \
        nc -n -z -w 3 "$lan_ip" 445 >/dev/null 2>&1
      then
        smb_host=$lan_ip
      fi

      printf 'mac-mini-smb-mount: using SMB host %s\n' "$smb_host"
      export RCLONE_SMB_HOST="$smb_host"
      export RCLONE_SMB_USER="$username"
      export RCLONE_SMB_PASS
      RCLONE_SMB_PASS=$(printf '%s\n' "$password" | rclone obscure -)
      unset password

      cache_root="''${XDG_CACHE_HOME:-$HOME/.cache}/rclone/mac-mini"
      mkdir -p "$cache_root"

      exec rclone mount :smb:glom "$mount_point" \
        --config /dev/null \
        --attr-timeout 1s \
        --contimeout 30s \
        --daemon-timeout 10s \
        --dir-cache-time 30s \
        --log-level NOTICE \
        --log-systemd \
        --low-level-retries 10 \
        --multi-thread-streams 0 \
        --poll-interval 0 \
        --retries 5 \
        --smb-idle-timeout 5m \
        --timeout 10m \
        --transfers 1 \
        --vfs-cache-mode full \
        --cache-dir "$cache_root" \
        --vfs-cache-max-age 24h \
        --vfs-cache-max-size 10Gi \
        --vfs-write-back 5s \
        --volname mac-mini
    '';
  };

  macMiniConnect = pkgs.writeShellApplication {
    name = "mac-mini-connect";
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      systemd
      util-linux
      wol
    ];
    text = ''
      mount_point=${lib.escapeShellArg mountPoint}
      service=mac-mini-smb.service
      attempt=0

      if ! systemctl --user cat "$service" >/dev/null 2>&1; then
        printf 'mac-mini-connect: %s is not installed\n' "$service" >&2
        exit 1
      fi

      trap 'exit 130' INT TERM
      mkdir -p "$mount_point"

      while true; do
        if [ $((attempt % 10)) -eq 0 ]; then
          # Wake both the wired and Wi-Fi interfaces when the Mac is sleeping.
          wol --host=192.168.50.255 \
            1c:f6:4c:59:e6:ea 1c:f6:4c:5b:cd:2f >/dev/null 2>&1 || true
        fi

        if ! systemctl --user is-active --quiet "$service"; then
          systemctl --user reset-failed "$service" >/dev/null 2>&1 || true
          systemctl --user start --no-block "$service" >/dev/null 2>&1 || true
        fi

        mount_type=$(findmnt -rn -o FSTYPE --target "$mount_point" 2>/dev/null || true)
        if [ "$mount_type" = "fuse.rclone" ] && \
          timeout --kill-after=2s 15s df -P -- "$mount_point" >/dev/null 2>&1
        then
          printf '%s\n' "$mount_point"
          exit 0
        fi

        attempt=$((attempt + 1))
        if [ $((attempt % 10)) -eq 0 ]; then
          # Recreate a mounted but unhealthy rclone session before retrying.
          systemctl --user restart --no-block "$service" >/dev/null 2>&1 || true
        fi
        sleep 3
      done
    '';
  };
in {
  home.packages = [macMiniConnect];

  systemd.user.services.mac-mini-smb = {
    Unit = {
      Description = "mac-mini SMB mount";
    };
    Service = {
      Type = "simple";
      ExecStart = "${macMiniSmbMount}/bin/mac-mini-smb-mount";
      ExecStopPost = "-/run/wrappers/bin/fusermount3 -u -z ${mountPoint}";
      KillMode = "mixed";
      Restart = "on-failure";
      RestartSec = "5s";
      TimeoutStopSec = "8s";
    };
  };
}
