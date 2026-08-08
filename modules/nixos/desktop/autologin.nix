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
  # niri-session re-execs itself through a login shell whenever $SHELL is
  # listed in /etc/shells (`exec -l "$SHELL" -c "$0 -l"`), which re-sources
  # /etc/profile and reaches this snippet a second time. NixOS' own
  # `__ETC_PROFILE_SOURCED` guard does not help: it is assigned without
  # `export`, so it does not survive the exec. Without an exported marker the
  # two conditions below are still true on that second pass and tty1 spins in
  # an endless exec loop instead of starting the compositor.
  environment.loginShellInit = ''
    if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" = 1 ] && [ -z "$NIRI_SESSION_LAUNCHED" ]; then
      export NIRI_SESSION_LAUNCHED=1
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
