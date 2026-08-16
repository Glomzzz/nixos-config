{
  config,
  pkgs,
  ...
}: let
  emacs = config.programs.emacs.finalPackage;
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
      if test (${emacs}/bin/emacsclient --alternate-editor= --eval '(if (my/gui-frames) (quote yes) (quote no))') = no
        ${emacs}/bin/emacsclient --create-frame --no-wait --suppress-output --alternate-editor= --eval '(my/magit-status-window default-directory)'
      else
        ${emacs}/bin/emacsclient --no-wait --suppress-output --alternate-editor= --eval '(my/magit-status-window default-directory)'
      end
      and echo "Magit opened in an Emacs window"
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
