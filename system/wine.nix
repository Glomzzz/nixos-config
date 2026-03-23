{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # winePackages.unstableFull
    wineWow64Packages.waylandFull
    wine64Packages.waylandFull
    # wine-staging
    wine64
    winetricks
    wine64Packages.fonts
  ];
}
