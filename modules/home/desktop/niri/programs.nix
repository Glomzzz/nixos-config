{
  config,
  lib,
  pkgs,
  ...
}: let
  androidMountPoint = "${config.home.homeDirectory}/mnt/android";
  androidPhone = pkgs.writeShellApplication {
    name = "android-phone";
    runtimeInputs = with pkgs; [
      android-file-transfer
      coreutils
      findutils
      libnotify
      util-linux
    ];
    text = ''
      mount_point=${lib.escapeShellArg androidMountPoint}

      report_error() {
        printf 'android-phone: %s\n' "$1" >&2
        notify-send --urgency=critical "Android phone" "$1" >/dev/null 2>&1 || true
      }

      get_mount_type() {
        findmnt -rn --mountpoint "$mount_point" -o FSTYPE 2>/dev/null || true
      }

      case "''${1:-mount}" in
        mount)
          mkdir -p "$mount_point"

          mount_type=$(get_mount_type)
          if [ -n "$mount_type" ]; then
            if [ "$mount_type" != "fuse.aft-mtp-mount" ]; then
              report_error "Refusing to replace unexpected filesystem: $mount_type"
              exit 1
            fi

            if mountpoint -q -- "$mount_point" 2>/dev/null; then
              exit 0
            fi

            if ! /run/wrappers/bin/fusermount3 -u -z "$mount_point"; then
              report_error "Could not detach the disconnected phone mount."
              exit 1
            fi
          fi

          if [ -n "$(find "$mount_point" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
            report_error "The mount directory is not empty: $mount_point"
            exit 1
          fi

          if ! mount_output=$(aft-mtp-mount "$mount_point" 2>&1); then
            report_error "Could not mount the phone. Unlock it and select File transfer (MTP)."
            if [ -n "$mount_output" ]; then
              printf '%s\n' "$mount_output" >&2
            fi
            rmdir "$mount_point" 2>/dev/null || true
            exit 1
          fi

          if ! mountpoint -q -- "$mount_point"; then
            report_error "The MTP mount exited without mounting the phone."
            rmdir "$mount_point" 2>/dev/null || true
            exit 1
          fi
          ;;
        unmount)
          mount_type=$(get_mount_type)
          if [ -z "$mount_type" ]; then
            rmdir "$mount_point" 2>/dev/null || true
            exit 0
          fi

          if [ "$mount_type" != "fuse.aft-mtp-mount" ]; then
            report_error "Refusing to unmount unexpected filesystem: $mount_type"
            exit 1
          fi

          if ! /run/wrappers/bin/fusermount3 -u "$mount_point"; then
            if mountpoint -q -- "$mount_point" 2>/dev/null; then
              report_error "The phone is busy. Close other programs using it and try again."
              exit 1
            fi

            if ! /run/wrappers/bin/fusermount3 -u -z "$mount_point"; then
              report_error "Could not detach the disconnected phone mount."
              exit 1
            fi
          fi

          rmdir "$mount_point" 2>/dev/null || true
          notify-send "Android phone" "Unmounted; it is safe to disconnect." >/dev/null 2>&1 || true
          ;;
        *)
          printf 'Usage: android-phone [mount|unmount]\n' >&2
          exit 2
          ;;
      esac
    '';
  };
in {
  # Viewers and daemons that KDE used to supply. Each entry here replaces a
  # Plasma component rather than adding something new.
  programs = {
    # Video player, replacing vlc.
    mpv = {
      enable = true;
      config = {
        hwdec = "auto-safe";
        vo = "gpu-next";
        gpu-api = "vulkan";
        profile = "high-quality";
        keep-open = true;
      };
    };
  };

  home.packages = with pkgs; [
    # FUSE-backed MTP mount used by the Dirvish Android commands.
    androidPhone

    # X11 shim so Steam/Discord/JetBrains keep working under niri.
    xwayland-satellite

    # Region select -> annotate -> save/clipboard. niri's own `screenshot`
    # action saves straight to disk with no editing step, so satty needs its
    # own path in. Bound to Mod+Shift+S in settings.nix.
    # niri spawns commands with a minimal environment, so coreutils is
    # referenced by store path rather than assumed to be on PATH.
    (writeShellScriptBin "screenshot-annotate" ''
      set -euo pipefail
      out="$HOME/Pictures/Screenshots"
      ${coreutils}/bin/mkdir -p "$out"
      stamp=$(${coreutils}/bin/date '+%Y%m%dT%H%M%S')
      ${grim}/bin/grim -g "$(${slurp}/bin/slurp -d)" -t ppm - \
        | ${satty}/bin/satty \
            --filename - \
            --fullscreen \
            --early-exit \
            --copy-command ${wl-clipboard}/bin/wl-copy \
            --output-filename "$out/satty-$stamp.png"
    '')
    satty
    grim
    slurp

    # Screen recording.
    wl-screenrec
    # wl-copy / wl-paste. cliphist depends on this.
    wl-clipboard

    # Image viewer, replacing loupe.
    oculante

    # Archive manager, replacing Ark and preventing PrismLauncher from becoming
    # the incidental default for ZIP files.
    file-roller

    # Fallback drag source for marked Dirvish files.  PGTK can initiate native
    # drags too; ripdrag remains useful for less cooperative XWayland targets.
    ripdrag

    # GUI/TUI control panels that replace the Plasma applets.
    overskride # Bluetooth
    wiremix # audio mixer
    # nmtui, not impala, for wifi: impala is an iwd front end and talks to
    # net.connman.iwd over D-Bus, but this host manages wifi with
    # NetworkManager over wpa_supplicant (modules/nixos/core/networking.nix,
    # wifi.backend=wpa_supplicant) and iwd is not installed at all. With no
    # iwd on the bus impala panics on startup instead of reporting the
    # missing backend, which is why clicking the netspeed module appeared to
    # do nothing. nmtui ships in the same networkmanager package the daemon
    # comes from, so the TUI and the daemon can never drift apart.
    networkmanager # nmtui, wifi
    # gnome-keyring front end (replaces kwalletmanager). Needed to change the
    # login keyring's own password, which is stored inside the keyring file and
    # so cannot be set declaratively. See modules/nixos/desktop/autologin.nix.
    seahorse

    # Hardware keys wired up in settings.nix.
    brightnessctl
    playerctl
  ];
}
