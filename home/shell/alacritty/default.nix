{ pkgs, ... }:

# terminals

let
  font = "JetBrainsMono Nerd Font";
in
{
  programs.alacritty = {
    enable = true;

    settings = {
      general.import = [
        ./catppuccin-mocha.toml
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
        # Spawn a nushell in login mode via `bash`
        shell = {
          program = "${pkgs.bash}/bin/bash";
          args = ["--login" "-c" "nu --login --interactive"];
        };
        # Controls the ability to write to the system clipboard with the OSC 52 escape sequence.
        # It's used by zellij to copy text to the system clipboard.
        osc52 = "CopyPaste";
      };
    };
  };
}