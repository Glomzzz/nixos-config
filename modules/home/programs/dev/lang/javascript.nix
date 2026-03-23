{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nodePackages.npm
    nodePackages.pnpm
    bun
  ];
}
