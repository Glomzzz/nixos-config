{
  pkgs,
  plasma-manager,
  ...
}:
{
  imports = [
    plasma-manager.homeModules.plasma-manager
  ];

  home.packages = with pkgs; [
    plasma-panel-colorizer
    kdePackages.kconfig
    kdePackages.plasma-thunderbolt
  ];

  programs.plasma = {
    enable = true;
    overrideConfig = false;
    kscreenlocker.lockOnStartup = false;
    kscreenlocker.passwordRequired = false;
  };

  # Disable KWallet password prompt on auto-login
  xdg.configFile."kwalletrc" = {
    text = ''
      [Wallet]
      Enabled=false
      Close When Idle=false
      Use One Wallet=true
      Default Wallet=kdewallet
    '';
    force = true;
  };
}
