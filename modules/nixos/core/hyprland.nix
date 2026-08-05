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
    # X11 clients use xwayland-satellite so their buffers can be scaled across
    # the 1.5x laptop panel and 1x HDMI output.
    xwayland.enable = false;
  };

  # Hyprland's portal does not implement Secret. Route it to the KWallet
  # backend so browsers can retrieve their persistent cookie encryption key.
  xdg.portal.config.hyprland = {
    default = [
      "hyprland"
      "gtk"
    ];
    "org.freedesktop.impl.portal.Secret" = ["kwallet"];
  };

  services.displayManager.defaultSession = "hyprland-uwsm";
}
