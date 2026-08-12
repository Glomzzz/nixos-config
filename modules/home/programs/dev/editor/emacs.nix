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
    });
    extraPackages = epkgs: [
      (epkgs.pdf-tools.overrideAttrs (old: {
        patches =
          (old.patches or [])
          ++ [
            ../../../../../patches/pdf-tools-native-comp-declarations.patch
            ../../../../../patches/pdf-tools-roll-overlay-safety.patch
          ];
      }))
    ];
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
    exec = "${emacs}/bin/emacs --dirvish %f";
    icon = "emacs";
    terminal = false;
    categories = ["System" "FileTools" "FileManager"];
    mimeType = ["inode/directory"];
    startupNotify = true;
  };
  xdg.mimeApps.defaultApplications = {
    "application/epub+zip" = ["emacs.desktop"];
    "application/json" = ["emacs.desktop" "emacsclient.desktop"];
    "application/pdf" = ["emacs.desktop"];
    "application/postscript" = ["emacs.desktop"];
    "application/x-shellscript" = ["emacs.desktop" "emacsclient.desktop"];
    "application/x-gzpostscript" = ["emacs.desktop"];
    "image/x-eps" = ["emacs.desktop"];
    "inode/directory" = ["emacs-dirvish.desktop"];
    "text/plain" = ["emacs.desktop" "emacsclient.desktop"];
    "text/x-c" = ["emacs.desktop" "emacsclient.desktop"];
    "text/x-c++" = ["emacs.desktop" "emacsclient.desktop"];
    "text/x-c++hdr" = ["emacs.desktop" "emacsclient.desktop"];
    "text/x-c++src" = ["emacs.desktop" "emacsclient.desktop"];
    "text/x-chdr" = ["emacs.desktop" "emacsclient.desktop"];
    "text/x-csrc" = ["emacs.desktop" "emacsclient.desktop"];
    "text/x-java" = ["emacs.desktop" "emacsclient.desktop"];
    "text/x-makefile" = ["emacs.desktop" "emacsclient.desktop"];
    "text/x-moc" = ["emacs.desktop" "emacsclient.desktop"];
    "text/x-pascal" = ["emacs.desktop" "emacsclient.desktop"];
    "text/x-tcl" = ["emacs.desktop" "emacsclient.desktop"];
    "text/x-tex" = ["emacs.desktop" "emacsclient.desktop"];
    "x-scheme-handler/org-protocol" = ["emacsclient.desktop"];
  };
  home.sessionVariables = {
    EDITOR = "emacsclient -c -a emacs";
    VISUAL = "emacsclient -c -a emacs";
    SUDO_EDITOR = "emacsclient -c -a emacs";
    ALTERNATE_EDITOR = "";
  };
}
