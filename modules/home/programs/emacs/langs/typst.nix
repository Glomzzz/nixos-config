{pkgs, ...}: {
  home.packages = with pkgs; [
    tinymist
    typstyle
  ];
}
