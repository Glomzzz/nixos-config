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
    anydesk
    # VNC/RDP/SPICE client, kept alongside anydesk because anydesk only speaks
    # its own protocol. nixpkgs builds remmina against libvncserver and freerdp
    # unconditionally, so the vnc plugin is present without extra options.
    remmina
    cherry-studio-with-desktop
  ];
}
