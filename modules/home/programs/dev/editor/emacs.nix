{
  pkgs,
  inputs,
  system,
  ...
}:
{
  # environment.systemPackages = [
  #   pkgs.emacs
  # ];
  home.packages = with pkgs; [
    emacs-pgtk
    libtool
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
    EDITOR = "emacs";
  };
}
