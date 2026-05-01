{
  lib,
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
    kdePackages.plasma-thunderbolt
  ];

  programs.plasma = {
    enable = true;
    overrideConfig = false;
    kscreenlocker = {
      autoLock = false;
      lockOnResume = false;
      lockOnStartup = false;
      passwordRequired = false;
      timeout = 0;
    };
  };

  # NetworkManager stores per-user Wi-Fi secrets in KWallet.
  xdg.configFile."kwalletrc" = {
    text = ''
      [Wallet]
      Enabled=true
      Close When Idle=false
      Use One Wallet=true
      Default Wallet=kdewallet
    '';
    force = true;
  };

  home.activation.disablePlasmaLoginPrompts = lib.hm.dag.entryAfter ["configure-plasma"] ''
    run mkdir -p "$HOME/.config"
    run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file "$HOME/.config/kscreenlockerrc" \
      --group Daemon \
      --key Autolock false
    run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file "$HOME/.config/kscreenlockerrc" \
      --group Daemon \
      --key LockOnResume false
    run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file "$HOME/.config/kscreenlockerrc" \
      --group Daemon \
      --key LockOnStart false
    run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file "$HOME/.config/kscreenlockerrc" \
      --group Daemon \
      --key RequirePassword false
    run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file "$HOME/.config/kscreenlockerrc" \
      --group Daemon \
      --key Timeout 0
  '';
}
