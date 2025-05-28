{
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    v2raya
    clash-verge-rev
    qq
    wechat-uos
    telegram-desktop
    mumble
    discord
  ];

}
