{
  inputs,
  pkgs,
  ...
}: let
  packages = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system};
in {
  programs.hyprland = {
    enable = true;
    package = packages.hyprland;
    portalPackage = packages.xdg-desktop-portal-hyprland;
    withUWSM = true;
    xwayland.enable = true;
  };

  services.displayManager.defaultSession = "hyprland-uwsm";
}
