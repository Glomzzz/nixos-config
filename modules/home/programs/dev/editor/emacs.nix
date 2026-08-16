{
  config,
  pkgs,
  ...
}: let
  emacs = config.programs.emacs.finalPackage;
  emc = "${config.home.homeDirectory}/.local/bin/emc";
in {
  programs.emacs = {
    enable = true;
    # Keep Emacs on the newest pretest (31.x): nixpkgs' emacs31-pgtk tracks
    # upstream pretest releases on each flake update.
    package = pkgs.emacs31-pgtk.overrideAttrs (old: {
      patches = (old.patches or []) ++ [../../../../../patches/emacs-cairo-interactive-image-filter.patch];
      # Emacs's C-level redisplay, image scaling, and GTK glue dominate
      # responsiveness; give them native codegen.
      NIX_CFLAGS_COMPILE = "-O2 -march=native";
    });
    # No extraPackages: every Lisp package comes from package.el
    # (~/.config/emacs/modules/bootstrap.el), not from Nix.
  };

  services.emacs = {
    enable = true;
    client = {
      enable = true;
      # Keep the same no-spawn guarantee for the desktop entry: an
      # empty alternate editor makes emacsclient fail loudly instead
      # of manufacturing a bare `emacs --daemon` orphan when the
      # daemon is briefly unreachable.
      arguments = ["-c" "--alternate-editor="];
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

  # Reap orphaned Emacs daemons before (re)starting the service:
  # emacsclient's alternate-editor fallback can still spawn a bare
  # `emacs --daemon=<socket>` during the brief window while the
  # service is restarting, and such processes keep a shadowed copy of
  # the server socket forever.  The pattern is anchored to the Emacs
  # binary invocation, so it never matches the service's own
  # `--fg-daemon` command line, and the leading '-' makes the pkill
  # ignore "no process matched".  The sleep gives a signaled orphan
  # time to release the socket path before the new daemon binds it.
  systemd.user.services.emacs.serviceConfig.ExecStartPre = [
    "-${pkgs.procps}/bin/pkill -f '^(/nix/store/[^ ]*/bin/)?emacs --daemon'"
    "${pkgs.coreutils}/bin/sleep 1"
  ];

  programs.fish.functions.magit = {
    description = "Open Magit for the current directory in an Emacs window";
    body = ''
      # A frame-less daemon cannot display a buffer: its display-less
      # initial frame wedges the PGTK daemon if Magit tries to use it.
      # Fall back to the client's --create-frame path in that case.
      if test (${emc} --alternate-editor= --eval '(if (my/gui-frames) (quote yes) (quote no))') = no
        ${emc} --create-frame --no-wait --suppress-output --alternate-editor= --eval '(my/magit-status-window default-directory)'
      else
        ${emc} --no-wait --suppress-output --alternate-editor= --eval '(my/magit-status-window default-directory)'
      end
      and echo "Magit opened in an Emacs window"
    '';
  };

  # emacsclient wrapper used by the niri binds and the `magit' fish
  # function: when the hand-written config is newer than the running
  # daemon and no frame is open (the launching client is the only
  # one), restart the daemon first so the edited config is loaded.
  #
  # The probe only asks for functions the daemon defines in core.el;
  # a daemon that cannot answer it is running some other config and
  # counts as stale, so the restart that loads the current config
  # always happens instead of serving void-function errors.
  home.file.".local/bin/emc" = {
    executable = true;
    text = ''
      #!/bin/sh
      # Resolve the client at runtime instead of relying on a bare
      # store path: prefer an explicit EMACSCLIENT, then the binary of
      # the generation this wrapper was built from, and fall back to
      # PATH.  A rolled-back or garbage-collected Emacs store path can
      # therefore never leave the wrapper broken.
      if [ -n "$EMACSCLIENT" ] && [ -x "$EMACSCLIENT" ]; then
        emacsclient=$EMACSCLIENT
      elif [ -x "${emacs}/bin/emacsclient" ]; then
        emacsclient=${emacs}/bin/emacsclient
      else
        emacsclient=$(command -v emacsclient || true)
      fi
      [ -n "$emacsclient" ] || { echo "emc: emacsclient not found" >&2; exit 1; }

      # systemctl lives at the stable system path (/run/current-system
      # is a boot-level GC root), unlike a per-generation store path.
      if [ "$("$emacsclient" --alternate-editor= --eval '(if (and (fboundp (quote my/gui-frames)) (fboundp (quote my/config-stale-p))) (if (and (null (my/gui-frames)) (my/config-stale-p)) (quote stale) (quote ok)) (quote stale))' 2>/dev/null)" = stale ]; then
        /run/current-system/sw/bin/systemctl --user restart emacs
      fi
      exec "$emacsclient" "$@"
    '';
  };

  home.packages = with pkgs; [
    # Runtime helpers for Dirvish previews.
    epub-thumbnailer
    ffmpegthumbnailer
    ghostscript
    imagemagick
    libtool
    mediainfo
    poppler-utils
    vips
  ];
  xdg.desktopEntries.emacs-dirvish = {
    name = "Emacs Dirvish";
    genericName = "File Manager";
    comment = "Manage files with Dirvish in Emacs";
    exec = "${emacs}/bin/emacsclient --create-frame --no-wait --alternate-editor= %f";
    icon = "emacs";
    terminal = false;
    categories = ["System" "FileTools" "FileManager"];
    mimeType = ["inode/directory"];
    startupNotify = true;
  };
  xdg.mimeApps.defaultApplications = {
    "application/epub+zip" = ["emacsclient.desktop"];
    "application/x-fishscript" = ["emacsclient.desktop"];
    "application/json" = ["emacsclient.desktop"];
    "application/pdf" = ["emacsclient.desktop"];
    "application/postscript" = ["emacsclient.desktop"];
    "application/x-shellscript" = ["emacsclient.desktop"];
    "application/x-gzpostscript" = ["emacsclient.desktop"];
    "image/x-eps" = ["emacsclient.desktop"];
    "inode/directory" = ["emacs-dirvish.desktop"];
    "text/plain" = ["emacsclient.desktop"];
    "text/x-c" = ["emacsclient.desktop"];
    "text/x-c++" = ["emacsclient.desktop"];
    "text/x-c++hdr" = ["emacsclient.desktop"];
    "text/x-c++src" = ["emacsclient.desktop"];
    "text/x-chdr" = ["emacsclient.desktop"];
    "text/x-csrc" = ["emacsclient.desktop"];
    "text/x-java" = ["emacsclient.desktop"];
    "text/x-makefile" = ["emacsclient.desktop"];
    "text/x-moc" = ["emacsclient.desktop"];
    "text/x-pascal" = ["emacsclient.desktop"];
    "text/x-tcl" = ["emacsclient.desktop"];
    "text/x-tex" = ["emacsclient.desktop"];
    "x-scheme-handler/org-protocol" = ["emacsclient.desktop"];
  };
  # EDITOR/VISUAL must keep an EMPTY alternate editor: while the daemon
  # is unreachable for a moment (e.g. mid-restart), a non-empty
  # alternate editor makes emacsclient spawn a bare `emacs --daemon`
  # process that shadows the service daemon's socket forever.  An
  # empty --alternate-editor= makes emacsclient fail loudly instead,
  # and the fish shell inherits these through home.sessionVariables.
  home.sessionVariables = {
    EDITOR = "emacsclient -c --alternate-editor=";
    VISUAL = "emacsclient -c --alternate-editor=";
    SUDO_EDITOR = "emacsclient -c --alternate-editor=";
    ALTERNATE_EDITOR = "";
  };
}
