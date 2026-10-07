{
  inputs,
  specialArgs,
  username,
  pkgs,
  ...
}: let
  userRoot = ../../../users + "/${username}";
in {
  home-manager = {
    # Preserve every displaced file; repeated activations must not overwrite
    # a previous backup or delete unrelated files in the user's home.
    backupCommand = let
      backup = pkgs.writeShellApplication {
        name = "home-manager-backup";
        runtimeInputs = [pkgs.coreutils];
        text = ''
          umask 077
          target="$1"
          case "$target" in
            "$HOME"/*) relative="''${target#"$HOME"/}" ;;
            *) printf 'Refusing to back up a path outside HOME: %s\n' "$target" >&2; exit 1 ;;
          esac

          root="''${XDG_STATE_HOME:-$HOME/.local/state}/home-manager/backups"
          mkdir -p -- "$root"
          backup_dir=$(mktemp -d "$root/$(date -u +%Y%m%dT%H%M%SZ).XXXXXX")
          destination="$backup_dir/$relative"
          mkdir -p -- "$(dirname "$destination")"
          mv -- "$target" "$destination"
          printf 'Home Manager backup: %s\n' "$destination" >&2
        '';
      };
    in "${backup}/bin/home-manager-backup";

    useGlobalPkgs = true;
    useUserPackages = true;

    users.${username} = {
      imports = [
        (import (userRoot + "/home.nix"))
      ];
    };
    extraSpecialArgs = inputs // specialArgs;
  };

  # NixOS does not automatically source user profile.d files. The system
  # Fish login hook execs niri before ~/.config/fish/config.fish is read, so
  # seed the session here as well as Home Manager's native Fish integration.
  # Resolve the current user's profile, never another user's session values.
  environment.extraInit = ''
    if [ -n "''${USER:-}" ]; then
      hm_session_vars="/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh"
      if [ -r "$hm_session_vars" ]; then
        . "$hm_session_vars"
      fi
      unset hm_session_vars
    fi
  '';
}
