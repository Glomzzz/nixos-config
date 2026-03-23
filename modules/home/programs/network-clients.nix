{pkgs, ...}: {
  home.packages = with pkgs; [
    v2raya
    easytier
  ];
}
