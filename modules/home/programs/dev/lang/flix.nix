{pkgs, ...}: {
  home.packages = with pkgs; [
    flix
  ];
}
