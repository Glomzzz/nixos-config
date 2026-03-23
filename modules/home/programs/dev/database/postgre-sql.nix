{ pkgs, ... }:
{
  home.packages = with pkgs; [
    pgcli
  ];
}
