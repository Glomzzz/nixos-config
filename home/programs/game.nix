{pkgs, ...}: {
  home.packages = with pkgs; [
    playonlinux
    lutris
    prismlauncher
    hmcl
    airshipper
  ];
}
