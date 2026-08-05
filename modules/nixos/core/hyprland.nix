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

  # Hyprland's portal does not implement Secret. Route it to the KWallet
  # backend so browsers can retrieve the same cookie encryption key as Plasma.
  xdg.portal.config.hyprland = {
    default = [
      "hyprland"
      "gtk"
    ];
    "org.freedesktop.impl.portal.Secret" = ["kwallet"];
  };

  services.displayManager.defaultSession = "hyprland-uwsm";
}
