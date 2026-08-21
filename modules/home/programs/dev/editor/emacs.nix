{
  config,
  pkgs,
  ...
}: let
  emacs = config.programs.emacs.finalPackage;
  emacsInit = "${config.home.homeDirectory}/.config/emacs/init.el";
  emc = "${config.home.homeDirectory}/.local/bin/emc";
  noSpawnEditor = "${pkgs.coreutils}/bin/false";
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
    # Lisp packages are managed by Emacs config.
  };

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
  systemd.user.services.emacs.Service.ExecStartPre = [
    "-${pkgs.procps}/bin/pkill -f '^(/nix/store/[^ ]*/bin/)?emacs --daemon'"
    "${pkgs.coreutils}/bin/sleep 1"
    # Install declarations before the real daemon loads the configuration.
    # `--eval` must precede `-l init.el`; Emacs loads init files before
    # processing ordinary command-line arguments.
    "${emacs}/bin/emacs -Q --batch --eval '(setq user-emacs-directory (expand-file-name \"~/.config/emacs/\") packages/bootstrap-mode t)' -l ${emacsInit}"
  ];

  programs.fish.functions.magit = {
    description = "Open Magit in a new Emacs window for the current directory";
    body = ''
      if not command git -C "$PWD" rev-parse --show-toplevel >/dev/null 2>/dev/null
        echo "magit: $PWD is not inside a Git repository" >&2
        return 1
      end

      # Always ask emacsclient for a fresh graphical frame.  The Elisp
      # entry point uses that request's selected frame, so existing Magit
      # windows are left untouched.
      ${emc} --create-frame --no-wait --suppress-output --alternate-editor=${noSpawnEditor} --eval '(my/magit-status-window default-directory)'
      and echo "Magit opened in a new Emacs window"
    '';
  };

  # emacsclient wrapper used by the niri binds and the `magit' fish
  # function: when the hand-written config is newer than the running
  # daemon and no frame is open (the launching client is the only
  # one), restart the daemon first so the edited config is loaded.
  #
  # The probe only asks for functions defined by modules/emc.el.
  # a daemon that cannot answer it is running some other config and
  # counts as stale, so the restart that loads the current config
  # always happens instead of serving void-function errors.
  home = {
    file.".local/bin/emc" = {
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

        no_spawn_editor=${noSpawnEditor}
        # A daemon blocked by an earlier asynchronous request must not make
        # every later launcher wait forever.  A failed health probe triggers
        # the managed service restart below.
        probe=$("$emacsclient" --timeout=5 --alternate-editor="$no_spawn_editor" --eval '(if (and (fboundp (quote my/gui-frames)) (fboundp (quote my/config-stale-p))) (if (and (null (my/gui-frames)) (my/config-stale-p)) (quote stale) (quote ok)) (quote stale))' 2>/dev/null || true)

        # systemctl lives at the stable system path (/run/current-system
        # is a boot-level GC root), unlike a per-generation store path.
        systemctl=/run/current-system/sw/bin/systemctl
        if [ "$probe" != ok ]; then
          "$systemctl" --user reset-failed emacs.service >/dev/null 2>&1 || true
          if ! "$systemctl" --user restart emacs.service; then
            echo "emc: failed to restart emacs.service" >&2
            exit 1
          fi
        fi
        exec "$emacsclient" --alternate-editor="$no_spawn_editor" "$@"
      '';
    };
    packages = with pkgs; [
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
    # An empty alternate editor tells emacsclient to launch `emacs --daemon`.
    # Use `false` instead so every editor entry fails cleanly while the managed
    # service is unavailable and can never shadow its socket with an orphan.
    sessionVariables = {
      EDITOR = "emacsclient -c --alternate-editor=${noSpawnEditor}";
      VISUAL = "emacsclient -c --alternate-editor=${noSpawnEditor}";
      SUDO_EDITOR = "emacsclient -c --alternate-editor=${noSpawnEditor}";
      ALTERNATE_EDITOR = noSpawnEditor;
    };
  };
  xdg.desktopEntries.emacs-dirvish = {
    name = "Emacs Dirvish";
    genericName = "File Manager";
    comment = "Manage files with Dirvish in Emacs";
    exec = "${emc} --create-frame --no-wait --alternate-editor=${noSpawnEditor} %f";
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
}
