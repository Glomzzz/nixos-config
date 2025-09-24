{ pkgs
, config
, ...
}: {
  home.packages = with pkgs; [
    v2raya
    qq
    wechat-uos
    telegram-desktop
    mumble
    discord
];
}
