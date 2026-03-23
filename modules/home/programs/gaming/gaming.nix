{ pkgs, ... }:
{
  home.packages = with pkgs; [
    mgba
    lutris
    r2modman
    prismlauncher
  ];
}
