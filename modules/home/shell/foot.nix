{pkgs, ...}: let
  font = "JetBrainsMono Nerd Font";
in {
  # foot is the Wayland-native terminal for this session.
  programs.foot = {
    enable = true;

    settings = {
      main = {
        # foot tokenizes `shell` into argv, so login/interactive flags belong
        # here rather than in a SHELL environment variable.
        shell = "${pkgs.nushell}/bin/nu --login --interactive";
        font = "${font}:size=14";
        pad = "4x4";
      };

      scrollback.lines = 10000;

      cursor = {
        style = "beam";
        blink = "yes";
      };

      mouse.hide-when-typing = "yes";

      security.osc52 = "enabled";

      # Catppuccin Mocha, ported from the previous alacritty theme.
      # foot takes RRGGBB with no leading '#'. This is [colors-dark] rather
      # than [colors] because [colors] is deprecated as of foot 1.26.
      colors-dark = {
        alpha = 0.93;
        background = "1e1e2e";
        foreground = "cdd6f4";
        cursor = "1e1e2e f5e0dc";

        regular0 = "45475a";
        regular1 = "f38ba8";
        regular2 = "a6e3a1";
        regular3 = "f9e2af";
        regular4 = "89b4fa";
        regular5 = "f5c2e7";
        regular6 = "94e2d5";
        regular7 = "bac2de";

        bright0 = "585b70";
        bright1 = "f38ba8";
        bright2 = "a6e3a1";
        bright3 = "f9e2af";
        bright4 = "89b4fa";
        bright5 = "f5c2e7";
        bright6 = "94e2d5";
        bright7 = "a6adc8";

        "16" = "fab387";
        "17" = "f5e0dc";

        selection-foreground = "1e1e2e";
        selection-background = "f5e0dc";
        urls = "89b4fa";

        # Colour pairs are "foreground background" on a single value.
        search-box-no-match = "1e1e2e f38ba8";
        search-box-match = "1e1e2e a6adc8";
      };

      key-bindings = {
        clipboard-copy = "Control+Shift+c XF86Copy";
        clipboard-paste = "Control+Shift+v XF86Paste";
        search-start = "Control+Shift+r";
        font-increase = "Control+plus Control+equal Control+KP_Add";
        font-decrease = "Control+minus Control+KP_Subtract";
        font-reset = "Control+0 Control+KP_0";
      };
    };
  };
}
