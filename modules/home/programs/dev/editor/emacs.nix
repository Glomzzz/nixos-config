{pkgs, ...}: {
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
    imagemagick
    libtool
  ];
  xdg.mimeApps.defaultApplications = {
    "application/json" = ["emacs.desktop" "emacsclient.desktop"];
    "application/x-shellscript" = ["emacs.desktop" "emacsclient.desktop"];
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
