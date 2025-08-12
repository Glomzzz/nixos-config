{ pkgs
, config
, ...
}: {
  home.packages = with pkgs; [
    v2raya
    pkgs.stable.qq
    wechat-uos
    telegram-desktop
    mumble
    discord
    syncplay
  ];
}
