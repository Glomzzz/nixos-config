{
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    v2raya
    clash-verge-rev
    microsoft-edge
    qq
    wechat-uos
    telegram-desktop
    mumble
  ];
  
}