{
  config,
  pkgs,
  ...
}: let
  emacs = config.programs.emacs.finalPackage;
in {
  programs.emacs = {
    enable = true;
    package = pkgs.emacs31-pgtk.overrideAttrs (old: {
      patches = (old.patches or []) ++ [../../../../../patches/emacs-cairo-interactive-image-filter.patch];
      # Emacs's C-level redisplay, image scaling, and GTK glue dominate
      # PDF-viewer responsiveness; give them native codegen like the
      # epdfinfo server below.
      NIX_CFLAGS_COMPILE = "-O2 -march=native";
    });
    extraPackages = epkgs: [
      epkgs.async
      (epkgs.pdf-tools.overrideAttrs (old: {
        patches =
          (old.patches or [])
          ++ [
            ../../../../../patches/pdf-tools-native-comp-declarations.patch
            ../../../../../patches/pdf-tools-roll-overlay-safety.patch
          ];
        # The epdfinfo server is built locally by the package's preBuild
        # (`make server/epdfinfo`); give its C++ the same native flags the
        # rest of the system gets.  The heavy lifting happens inside poppler
        # and cairo, but the server's own PNG encode path benefits too.
        NIX_CFLAGS_COMPILE = "-O3 -march=native";
      }))
    ];
  };

  services.emacs = {
    enable = true;
    client.enable = true;
    socketActivation.enable = true;
    startWithUserSession = "graphical";
  };

  programs.fish.functions.magit = {
    description = "Open Magit for the current directory";
    body = ''
      ${emacs}/bin/emacsclient --create-frame --no-wait --suppress-output --alternate-editor= --eval '(magit-status default-directory)'
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
