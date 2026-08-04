{pkgs, ...}: let
  font = "JetBrainsMono Nerd Font";
in {
  programs.kitty = {
    enable = true;
    themeFile = "Catppuccin-Mocha";

    font = {
      name = font;
      size = 14;
    };

    settings = {
      bold_font = "auto";
      italic_font = "auto";
      bold_italic_font = "auto";
      background_opacity = 0.93;
      remember_window_size = false;
      initial_window_width = 1200;
      initial_window_height = 800;
      scrollback_lines = 10000;
      shell = "${pkgs.nushell}/bin/nu --login --interactive";
      clipboard_control = "write-clipboard write-primary read-clipboard read-primary";

      # Approximate Alacritty's dim foreground against the Mocha background.
      dim_opacity = 0.55;
      color16 = "#fab387";
      color17 = "#f5e0dc";
    };
  };
}
