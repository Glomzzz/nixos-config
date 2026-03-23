{pkgs, ...}: {
  home.packages = with pkgs; [
    wineWow64Packages.waylandFull
    winetricks
    wine64Packages.fonts
  ];
}
