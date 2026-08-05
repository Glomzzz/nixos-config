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
    configFile = {
      kdeglobals.General = {
        TerminalApplication = "kitty";
        TerminalService = "kitty.desktop";
      };

      # kde-gtk-config's color reload module leaves a stale GFileMonitor
      # callback when kded6 is used in Hyprland, crashing GLib apps together.
      kded6rc."Module-gtkconfig".autoload = false;
    };
    shortcuts = {
      "services/Alacritty.desktop".New = [];
      "services/kitty.desktop"."_launch" = "Ctrl+Alt+T";
    };
    kscreenlocker = {
      autoLock = false;
      lockOnResume = false;
      lockOnStartup = false;
      passwordRequired = false;
      timeout = 0;
    };
  };

  # nm-applet stores user-owned Wi-Fi secrets through Secret Service, backed
  # by KWallet. System-owned profiles remain in root-only NetworkManager files.
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
