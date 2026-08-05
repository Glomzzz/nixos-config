_: {
  # nm-applet stores user-owned Wi-Fi secrets through Secret Service, backed
  # by KWallet. System-owned profiles remain in root-only NetworkManager files.
  xdg.configFile = {
    "kwalletrc" = {
      text = ''
        [Wallet]
        Enabled=true
        Close When Idle=false
        Use One Wallet=true
        Default Wallet=kdewallet
      '';
      force = true;
    };

    # programs.nm-applet already installs a managed user service. Shadow its
    # global autostart entry so a second secret agent cannot race that service.
    "autostart/nm-applet.desktop" = {
      text = ''
        [Desktop Entry]
        Type=Application
        Name=NetworkManager Applet
        Hidden=true
      '';
      force = true;
    };
  };
}
