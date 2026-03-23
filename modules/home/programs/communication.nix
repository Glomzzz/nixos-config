{pkgs, ...}: {
  home.packages = with pkgs; [
    qq
    wechat-uos
    telegram-desktop
    mumble
    discord
    feishu
  ];
}
