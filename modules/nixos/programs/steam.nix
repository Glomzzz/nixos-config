{pkgs, ...}: let
  # Use `steam-game-laptop %command%` as a game's Steam launch option when it
  # needs a fullscreen surface sized for the laptop panel.
  steamGameLaptop = pkgs.writeShellApplication {
    name = "steam-game-laptop";
    text = ''
      # Older system generations exported an NVIDIA ICD filename that no
      # longer exists. Drop only that stale override so an already-running
      # desktop session can still start Gamescope after switching generations.
      if [[ -n "''${VK_DRIVER_FILES:-}" && ! -e "''${VK_DRIVER_FILES}" ]]; then
        unset VK_DRIVER_FILES
      fi

      # Just Go only exposes 16:9 modes. Match the game's render surface to its
      # highest supported mode so Unity, Gamescope, and absolute input use the
      # same coordinates; Gamescope letterboxes it on the 16:10 panel.
      if [[ "''${SteamAppId:-''${STEAM_COMPAT_APP_ID:-}}" == "1862520" ]]; then
        set -- "$@" \
          -screen-width 2560 \
          -screen-height 1440 \
          -screen-fullscreen 1
      fi

      # Niri presents eDP-1 as 1707x1066 logical pixels at scale 1.5. Let the
      # Wayland backend negotiate that outer surface while the nested game
      # remains at the panel's native 2560x1600 pixels.
      exec ${pkgs.gamescope}/bin/gamescope \
        --backend wayland \
        --fullscreen \
        --nested-width 2560 \
        --nested-height 1600 \
        --nested-refresh 240 \
        --nested-unfocused-refresh 60 \
        --force-windows-fullscreen \
        --force-grab-cursor \
        --adaptive-sync \
        -- "$@"
    '';
  };
in {
  environment.systemPackages = with pkgs; [
    wayvr
    openxr-loader
    alvr
    gamescope
    steamGameLaptop
  ];

  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      # Steam multiplies this by the 1.6x DPI reported through Xwayland.
      # Its CEF UI clamps at 1x, so the reciprocal prevents another HiDPI
      # enlargement on Niri's 1.5x laptop output.
      extraEnv.STEAM_FORCE_DESKTOPUI_SCALING = "0.625";
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
