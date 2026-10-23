{
  config,
  pkgs,
  ...
}: let
  emacs = config.programs.emacs.finalPackage;
  emacsInit = "${config.home.homeDirectory}/.config/emacs/init.el";
  noSpawnEditor = "${pkgs.coreutils}/bin/false";
in {
  services.emacs = {
    enable = true;
    client = {
      enable = true;
      # A non-empty command that always fails makes emacsclient report
      # an unavailable server without spawning an unmanaged daemon.
      arguments = ["-c" "--alternate-editor=${noSpawnEditor}"];
    };
    # Socket activation is disabled on purpose: the generated
    # emacs.socket unit listens on %t/emacs/server while the daemon
    # also binds that exact path, and after every service restart
    # systemd's listener wins the path.  Client handshakes then fail,
    # and emacsclient's alternate-editor fallback spawns orphan
    # `emacs --daemon=<socket>` processes that shadow the real daemon
    # forever.  The service is already started by
    # graphical-session.target, and Emacs binds %t/emacs/server itself
    # (its default socket dir under XDG_RUNTIME_DIR), so the socket
    # unit's listener is redundant as well as harmful.
    socketActivation.enable = false;
    startWithUserSession = "graphical";
  };

  # Reap legacy orphaned Emacs daemons before (re)starting the service.
  # An orphan can keep a shadowed copy of the server socket forever.
  # The pattern is anchored to the Emacs binary invocation, so it never
  # matches the service's own `--fg-daemon` command line.  The leading '-'
  # makes "no process matched" harmless.  The sleep gives a signaled orphan
  # time to release the socket path before the new daemon binds it.
  systemd.user.services.emacs.Service = {
    # The system ncurses database has an older foot entry without Tc.  The
    # daemon does not inherit Foot's TERMINFO, so prefer Foot's own database
    # to detect true color without forcing it on less capable TTY clients.
    Environment = ["TERMINFO=${pkgs.foot.terminfo}/share/terminfo"];
    # The session manager may still have GTK_IM_MODULE=fcitx imported from
    # before a rebuild. Do not let it force the flickering GTK3 client-side
    # input panel; PGTK should use native Wayland text-input-v3 instead.
    UnsetEnvironment = ["GTK_IM_MODULE"];
    # A first launch may need to download and compile the entire package set.
    # Home Manager's default 90-second deadline is too short for that work.
    TimeoutStartSec = "5min";
    ExecStartPre = [
      "-${pkgs.procps}/bin/pkill -f '^(/nix/store/[^ ]*/bin/)?emacs --daemon'"
      "${pkgs.coreutils}/bin/sleep 1"
      # Install declarations before the real daemon loads the configuration.
      # `--eval` must precede `-l init.el`; Emacs loads init files before
      # processing ordinary command-line arguments.
      "${emacs}/bin/emacs -Q --batch --eval '(setq user-emacs-directory (expand-file-name \"~/.config/emacs/\") user-init-file ${builtins.toJSON emacsInit} packages/bootstrap-mode t)' -l ${emacsInit}"
    ];
  };
}
