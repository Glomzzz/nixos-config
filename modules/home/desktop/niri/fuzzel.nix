{pkgs, ...}: {
  # fuzzel is the launcher and dmenu replacement. It reads XDG .desktop entries,
  # so anything installed through home.packages shows up without extra wiring.
  programs.fuzzel = {
    enable = true;

    settings = {
      main = {
        terminal = "${pkgs.foot}/bin/foot";
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

  home.packages = [pkgs.papirus-icon-theme];
}
