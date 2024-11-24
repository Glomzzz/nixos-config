{ pkgs, ... }:

{

  time.timeZone = "Asia/Singapore";
  security.rtkit.enable = true;
  i18n = {
    defaultLocale = "en_SG.UTF-8";
    supportedLocales = [
      "en_SG.UTF-8/UTF-8"
      "zh_CN.UTF-8/UTF-8"
    ];
    inputMethod = {
      enabled = "fcitx5";

      fcitx5 = {
        waylandFrontend = true; #
        plasma6Support = true; #不用kde6 貌似不用启用
        addons = with pkgs; [
          fcitx5-chinese-addons
          fcitx5-gtk 
          libsForQt5.fcitx5-qt
          rime-data
          fcitx5-rime
          librime
        ];

      };
    };
    extraLocaleSettings = {
      LC_ADDRESS = "en_SG.UTF-8";
      LC_IDENTIFICATION = "en_SG.UTF-8";
      LC_MEASUREMENT = "en_SG.UTF-8";
      LC_MONETARY = "en_SG.UTF-8";
      LC_NAME = "en_SG.UTF-8";
      LC_NUMERIC = "en_SG.UTF-8";
      LC_PAPER = "en_SG.UTF-8";
      LC_TELEPHONE = "en_SG.UTF-8";
      LC_TIME = "en_SG.UTF-8";
  };
  };

}