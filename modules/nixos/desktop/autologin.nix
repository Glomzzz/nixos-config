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
  #
  # NIRI_SESSION_LAUNCHED is the re-entry guard and it MUST be exported.
  # niri-session re-execs itself through Fish because $SHELL is listed in
  # /etc/shells (`exec -l "$SHELL" -c "$0 -l"`), which reaches this login
  # initialization a second time. Without the exported marker, tty1 spins in
  # an endless exec loop instead of starting the compositor.
  #
  # This must be native Fish code. NixOS evaluates environment.loginShellInit
  # through a POSIX compatibility subprocess, where `exec` would replace only
  # that subprocess and leave the original tty shell behind after niri exits.
  programs.fish.loginShellInit = ''
    if not set --query WAYLAND_DISPLAY; and test "$XDG_VTNR" = 1; and not set --query NIRI_SESSION_LAUNCHED
      set --global --export NIRI_SESSION_LAUNCHED 1
      exec ${pkgs.niri}/bin/niri-session
    end
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
