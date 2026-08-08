{
  pkgs,
  username,
  ...
}: {
  # No display manager. getty logs the user in on tty1 and the login shell
  # execs niri-session, so the compositor is PID-owned by the user's session
  # rather than by a greeter process.
  services.getty.autologinUser = username;

  # `exec` replaces the shell, so logging out of niri ends the tty session
  # instead of dropping to a prompt behind the dead compositor. The tty1 guard
  # keeps other VTs and SSH usable as plain shells, and the WAYLAND_DISPLAY
  # check stops a nested relaunch from a terminal inside niri.
  environment.loginShellInit = ''
    if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
      exec ${pkgs.niri}/bin/niri-session
    fi
  '';

  # Autologin means PAM never sees a password, so pam_gnome_keyring cannot
  # unlock the login keyring at login. The keyring itself must therefore have
  # an empty password; once it does, gnome-keyring-daemon opens it unprompted.
  # The daemon is started by the niri session (systemd user units from
  # services.gnome.gnome-keyring), not by PAM.
  #
  # security.pam.services.login.enableGnomeKeyring is left at its default
  # (true, set by the gnome-keyring module) so that a manual login on another
  # VT still hands the password to the keyring.
}
