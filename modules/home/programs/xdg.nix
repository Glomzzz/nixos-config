{pkgs, ...}: {
  # If u meet error when switch:
  # journalctl -xe -u home-manager-<your-username>.service
  # check if there are file that already exist, if so, try to remove it
  xdg = {
    enable = true;
    userDirs.enable = true;
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/plain" = ["emacsclient.desktop" "emacs.desktop"];
        "text/x-c" = ["emacsclient.desktop" "emacs.desktop"];
        "text/x-c++" = ["emacsclient.desktop" "emacs.desktop"];
        "text/x-c++hdr" = ["emacsclient.desktop" "emacs.desktop"];
        "text/x-c++src" = ["emacsclient.desktop" "emacs.desktop"];
        "text/x-chdr" = ["emacsclient.desktop" "emacs.desktop"];
        "text/x-csrc" = ["emacsclient.desktop" "emacs.desktop"];
        "text/x-java" = ["emacsclient.desktop" "emacs.desktop"];
        "text/x-makefile" = ["emacsclient.desktop" "emacs.desktop"];
        "text/x-moc" = ["emacsclient.desktop" "emacs.desktop"];
        "text/x-pascal" = ["emacsclient.desktop" "emacs.desktop"];
        "text/x-tcl" = ["emacsclient.desktop" "emacs.desktop"];
        "text/x-tex" = ["emacsclient.desktop" "emacs.desktop"];
        "application/x-shellscript" = ["emacsclient.desktop" "emacs.desktop"];
        "x-scheme-handler/org-protocol" = ["emacsclient.desktop"];
      };
    };
  };

  home.packages = with pkgs; [
    xdg-utils
    handlr
  ];
}
