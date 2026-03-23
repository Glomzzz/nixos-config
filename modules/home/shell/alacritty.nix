{pkgs, ...}:
let
  font = "JetBrainsMono Nerd Font";
in {
  programs.alacritty = {
    enable = true;

    settings = {
      general.import = [
        ./alacritty/catppuccin-mocha.toml
      ];
      window = {
        opacity = 0.93;
        dynamic_title = true;
      };
      scrolling = {
        history = 10000;
      };
      font = {
        normal.family = font;
        bold.family = font;
        italic.family = font;
        bold_italic.family = font;
        size = 14;
      };
      terminal = {
        shell = {
          program = "${pkgs.bash}/bin/bash";
          args = ["--login" "-c" "nu --login --interactive"];
        };
        osc52 = "CopyPaste";
      };
    };
  };
}
