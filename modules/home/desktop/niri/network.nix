{config, ...}: {
  services.network-manager-applet.enable = true;

  # Waybar uses StatusNotifierItem, not the legacy XEmbed tray protocol.
  # This selects nm-applet --indicator without enabling an X11 session.
  xsession.preferStatusNotifierItems = true;

  # The service module supplies the applet and its icons, but does not install
  # the connection editor's desktop entry into the user's application menu.
  home.packages = [config.services.network-manager-applet.package];

  # niri also starts XDG autostart entries. Let the systemd service own the
  # only instance, with --indicator, instead of starting a second applet.
  xdg.configFile."autostart/nm-applet.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=NetworkManager Applet
    Hidden=true
  '';
}
