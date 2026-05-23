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
    };
  };

  home.packages = with pkgs; [
    xdg-utils
    handlr
  ];
}
