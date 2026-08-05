{pkgs, ...}: let
  emacs = (pkgs.emacsPackagesFor pkgs.emacs-pgtk).emacsWithPackages (epkgs: [
    epkgs.apheleia
    epkgs.flymake-eslint
    epkgs.typescript-mode
  ]);
in {
  # environment.systemPackages = [
  #   pkgs.emacs
  # ];
  home.packages = [
    emacs
    pkgs.libtool
  ];
  # programs.emacs = {
  #   enable = true;
  #   package = pkgs.emacs; # replace with pkgs.emacs-gtk if desired
  #   extraPackages = epkgs: [
  #     epkgs.nix-mode
  #     epkgs.nixfmt
  #   ];
  # };

  home.sessionVariables = {
    EDITOR = "emacsclient -c -a emacs";
    VISUAL = "emacsclient -c -a emacs";
    SUDO_EDITOR = "emacsclient -c -a emacs";
    ALTERNATE_EDITOR = "";
  };
}
