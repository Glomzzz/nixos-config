{
  config,
  pkgs,
  ...
}: let
  # Steam writes a launcher for every installed game and for SteamVR as
  # `Exec=steam steam://rungameid/<appid>` in ~/.local/share/applications, and
  # SteamVR's URI handlers run from steamapps/common. Fuzzel cannot filter by
  # Exec, so this wrapper points XDG_DATA_HOME at a filtered copy of that
  # applications directory. --launch-prefix restores the real XDG_DATA_HOME for
  # launched apps, so they never reference the temporary copy.
  app-launcher = pkgs.writeShellApplication {
    name = "app-launcher";
    runtimeInputs = [pkgs.fuzzel pkgs.coreutils pkgs.findutils pkgs.gnugrep];
    text = ''
      data_home="''${XDG_DATA_HOME:-$HOME/.local/share}"
      apps="$data_home/applications"
      stage="$(mktemp -d "''${XDG_RUNTIME_DIR:-/tmp}/app-launcher.XXXXXX")"
      trap 'rm -rf -- "$stage"' EXIT

      mkdir -- "$stage/applications"
      # Icons are looked up under XDG_DATA_HOME as well, so keep them reachable.
      if [ -d "$data_home/icons" ]; then
        ln -s -- "$data_home/icons" "$stage/icons"
      fi
      if [ -d "$apps" ]; then
        while IFS= read -r -d "" entry; do
          if grep -q -E '^Exec=.*(steam://rungameid/|steamapps/common/)' -- "$entry" 2>/dev/null; then
            continue
          fi
          rel="''${entry#"$apps"/}"
          mkdir -p -- "$stage/applications/$(dirname -- "$rel")"
          ln -s -- "$entry" "$stage/applications/$rel"
        done < <(find -L "$apps" -name '*.desktop' -print0)
      fi

      XDG_DATA_HOME="$stage" fuzzel \
        --launch-prefix="${pkgs.coreutils}/bin/env XDG_DATA_HOME=$data_home" "$@"
    '';
  };
in {
  # fuzzel is the launcher and dmenu replacement. It reads XDG .desktop entries,
  # so anything installed through home.packages shows up without extra wiring.
  programs.fuzzel = {
    enable = true;

    settings = {
      main = {
        terminal = "${config.programs.kitty.package}/bin/kitty";
        layer = "overlay";
        font = "JetBrainsMono Nerd Font:size=13";
        prompt = "'  '";
        width = 45;
        lines = 12;
        horizontal-pad = 16;
        vertical-pad = 12;
        inner-pad = 6;
        icon-theme = "Papirus-Dark";
      };

      border = {
        width = 2;
        radius = 8;
      };

      # Catppuccin Mocha. fuzzel wants RRGGBBAA with no leading '#'.
      colors = {
        background = "1e1e2eee";
        text = "cdd6f4ff";
        match = "89b4faff";
        selection = "45475aff";
        selection-text = "cdd6f4ff";
        selection-match = "89b4faff";
        border = "89b4faff";
      };
    };
  };

  home.packages = [pkgs.papirus-icon-theme app-launcher];
}
