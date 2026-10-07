{
  lib,
  pkgs,
  ...
}: {
  # Password login on tty1 keeps the existing Fish -> niri flow without a
  # display manager. PAM receives the password and unlocks the login keyring.
  services.getty.autologinUser = null;
  security.pam.services.login = {
    allowNullPassword = lib.mkForce false;
    enableGnomeKeyring = true;
  };

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

  # Set the existing Login keyring's password interactively in Seahorse to
  # match the account password. Never store that password in Nix or the store.
  # See docs/authentication.md for migration and recovery instructions.
}
