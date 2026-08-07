{
  config,
  pkgs,
  ...
}: {
  home.sessionVariables.WINEPREFIX = "${config.xdg.dataHome}/wine";

  home.packages = with pkgs; [
    wineWow64Packages.waylandFull
    winetricks
    wine64Packages.fonts
  ];
}
