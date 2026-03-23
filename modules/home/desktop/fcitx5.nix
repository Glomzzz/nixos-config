{pkgs, ...}: {
  home.sessionVariables = {
    XMODIFIERS = "@im=fcitx";
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      qt6Packages.fcitx5-chinese-addons
      rime-data
      fcitx5-rime
      fcitx5-mozc
      fcitx5-gtk
    ];
  };
}
