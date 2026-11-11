{pkgs, ...}: {
  # Remmina creates this entry whenever its tray icon is enabled. Keep the
  # entry present but disabled so it remains available on demand without
  # starting an applet at login.
  xdg.configFile."autostart/remmina-applet.desktop" = {
    force = true;
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Remmina Applet
      Hidden=true
    '';
  };

  home.packages = with pkgs; [
    qq
    wechat
    telegram-desktop
    mumble
    discord
    # anydesk is temporarily removed: nixpkgs' pinned hash no longer matches the
    # re-published 8.1.0 tarball. Re-add it once nixpkgs updates the hash.
    # VNC/RDP/SPICE client. nixpkgs builds remmina against libvncserver and freerdp
    # unconditionally, so the vnc plugin is present without extra options.
    remmina
    cherry-studio-with-desktop
  ];
}
