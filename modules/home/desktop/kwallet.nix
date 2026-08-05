_: {
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
}
