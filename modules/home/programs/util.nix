{ pkgs, ... }:
{
  home.packages = with pkgs; [
    wget
    usbutils
    yq-go
    curl
    sysstat
  ];

}
