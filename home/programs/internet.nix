{
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    v2raya
    clash-verge-rev
    pkgs.stable.qq
    wechat-uos
    telegram-desktop
    mumble
    discord
    syncplay
  ];

}
