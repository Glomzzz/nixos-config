{pkgs, ...}: {
  home.packages = with pkgs; [
    qq
    wechat
    telegram-desktop
    mumble
    discord
    anydesk
    kdePackages.krdc
    cherry-studio-with-desktop
  ];
}
