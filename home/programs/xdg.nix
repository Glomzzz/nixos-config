{ config, pkgs, ... }:

{
  # If u meet error when switch:
  # journalctl -xe -u home-manager-<your-username>.service
  # check if there are file that already exist, if so, try to remove it
  xdg = {
    enable = true; # Enable XDG 
    userDirs.enable = true;
  };
  home.packages = with pkgs; [
     xdg-utils
     handlr
  ];
}