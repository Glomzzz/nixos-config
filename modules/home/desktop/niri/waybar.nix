{
  config,
  lib,
  pkgs,
  ...
}: let
  helpers = import ./waybar/helpers.nix {inherit pkgs;};
in {
  programs.waybar = {
    enable = true;
    systemd = {
      enable = true;
      # niri.service binds to graphical-session.target.
      enableInspect = false;
    };
    settings.main = import ./waybar/settings.nix {
      inherit config lib pkgs helpers;
    };
    style = builtins.readFile ./waybar/style.css;
  };
}
