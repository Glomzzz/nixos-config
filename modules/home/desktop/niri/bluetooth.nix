_: {
  # NixOS enables services.blueman for the system D-Bus/polkit integration.
  services.blueman-applet.enable = true;

  # Match Blueman's D-Bus activation entry so opening the manager and starting
  # the session service share one applet, including its pairing agent.
  systemd.user.services.blueman-applet.Service = {
    Type = "dbus";
    BusName = "org.blueman.Applet";
  };

  # Waybar already owns the Bluetooth indicator and connected-device tooltip.
  # ShowConnected depends on StatusIcon and would otherwise load it again.
  dconf.settings."org/blueman/general".plugin-list = [
    "!StatusIcon"
    "!ShowConnected"
  ];

  # niri also runs XDG autostart entries; let the session service own startup.
  xdg.configFile."autostart/blueman.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Blueman Applet
    Hidden=true
  '';
}
