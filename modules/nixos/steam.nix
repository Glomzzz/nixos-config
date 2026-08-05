{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    wayvr
    openxr-loader
    alvr
    gamescope
  ];

  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      # Hyprland scales XWayland surfaces, so Steam must not multiply that
      # scale with its own persisted accessibility setting.
      extraEnv.STEAM_FORCE_DESKTOPUI_SCALING = "1";
    };
    fontPackages = with pkgs; [source-han-sans];
    extraPackages = with pkgs; [
      corefonts
      noto-fonts-cjk-sans
      source-han-sans
      # SteamVR's native vrmonitor is a Qt5 application, but the stock Steam
      # runtime does not provide the Qt5 libraries it links against.
      qt5.qtbase
      qt5.qtmultimedia
      qt5.qtwayland
    ];
    extraCompatPackages = with pkgs; [
      gamemode
      gamescope
      dxvk
      vkd3d
      mangohud
    ];
  };
}
