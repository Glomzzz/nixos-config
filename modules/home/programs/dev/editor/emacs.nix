{pkgs, ...}: {
  home.packages = with pkgs; [
    emacs-pgtk
    libtool
  ];

  home.sessionVariables = {
    EDITOR = "emacsclient -c -a emacs";
    VISUAL = "emacsclient -c -a emacs";
    SUDO_EDITOR = "emacsclient -c -a emacs";
    ALTERNATE_EDITOR = "";
  };
}
