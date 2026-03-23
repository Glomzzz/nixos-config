{pkgs, ...}: {
  home.packages = with pkgs; [
    protonplus
    mgba
    playonlinux
    lutris
    prismlauncher
    hmcl
    airshipper
    r2modman
  ];
}
