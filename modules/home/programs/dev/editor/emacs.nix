{pkgs, ...}: {
  home.packages = with pkgs; [
    emacs-pgtk
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
