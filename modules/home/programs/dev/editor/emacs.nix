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
    client.enable = true;
    socketActivation.enable = true;
    startWithUserSession = "graphical";
  };

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
      if [ "$(${emacs}/bin/emacsclient --alternate-editor= --eval '(if (and (fboundp (quote my/gui-frames)) (fboundp (quote my/config-stale-p))) (if (and (null (my/gui-frames)) (my/config-stale-p)) (quote stale) (quote ok)) (quote stale))' 2>/dev/null)" = stale ]; then
        ${pkgs.systemd}/bin/systemctl --user restart emacs
      fi
      exec ${emacs}/bin/emacsclient "$@"
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
  home.sessionVariables = {
    EDITOR = "emacsclient -c --alternate-editor=";
    VISUAL = "emacsclient -c --alternate-editor=";
    SUDO_EDITOR = "emacsclient -c --alternate-editor=";
    ALTERNATE_EDITOR = "";
  };
}
