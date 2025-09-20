{ pkgs
, config
, ...
}: {
  home.packages = with pkgs; [
    v2raya
    pkgs.legacy-2411.qq
    wechat-uos
    telegram-desktop
    mumble
    discord
    syncplay
  ];
}
