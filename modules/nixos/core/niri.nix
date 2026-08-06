{lib, ...}: {
  services = {
    clavis-shell.enable = true;
    displayManager.defaultSession = "niri";
    gnome.gnome-keyring.enable = false;
  };

  # Niri's portal stack does not implement Secret. Route it to KWallet so
  # browsers can retrieve their persistent cookie encryption key.
  xdg.portal.config.niri."org.freedesktop.impl.portal.Secret" =
    lib.mkForce "kwallet";
}
