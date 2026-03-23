{
  pkgs,
  plasma-manager,
  ...
}: {
  imports = [
    plasma-manager.homeModules.plasma-manager
  ];

  home.packages = with pkgs; [
    plasma-panel-colorizer
    kdePackages.kconfig
  ];

  programs.plasma = {
    enable = true;
    overrideConfig = false;
    kscreenlocker.lockOnStartup = true;
    kscreenlocker.passwordRequired = true;
  };
}
