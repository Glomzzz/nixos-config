_: {
  # udisks2 is the system D-Bus service that the Home Manager udiskie daemon
  # (modules/services/home/udiskie.nix) talks to for removable-media mounting.
  # It used to be enabled implicitly by the NixOS plasma6 module, so removing
  # KDE silently took it away and left udiskie.service crashing at login with
  # "org.freedesktop.UDisks2 ... name is not activatable". Enabling it here
  # keeps auto-mounting working under niri, where nothing else pulls it in.
  services.udisks2.enable = true;
}
