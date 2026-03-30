{ pkgs, ... }:
{
  home.packages = with pkgs; [
    qq
    (callPackage ../../../pkgs/wechat { })
    telegram-desktop
    mumble
    discord
    anydesk
  ];
}
