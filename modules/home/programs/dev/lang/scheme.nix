{pkgs, ...}: {
  home.packages = with pkgs; [
    chez
    racket
  ];
}
