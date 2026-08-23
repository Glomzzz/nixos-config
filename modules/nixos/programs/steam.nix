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
    gamescope
    steamGameLaptop
  ];

  programs.steam = {
    enable = true;
    # Steam Link on Quest 3 uses Steam Remote Play for the local VR stream.
    remotePlay.openFirewall = true;
    package = pkgs.steam.override {
      # Do not pass -pipewire: it routes Steam's desktop/Remote Play capture
      # into the PipeWire+EGL pipeline that cannot initialize on NVIDIA
      # Wayland hosts (Steam logs "CDesktopCapturePipeWire: Couldn't initialize
      # EGL: 0x3001"; upstream valve-software/steam-for-linux#10315/#11913),
      # and the ALVR use case it was added for is gone.
      extraArgs = "";
      # Steam multiplies this by the 1.6x DPI reported through Xwayland.
      # Its CEF UI clamps at 1x, so the reciprocal prevents another HiDPI
      # enlargement on Niri's 1.5x laptop output.
      # SteamVR and every game launched by Steam must select the NVIDIA GPU.
      extraEnv = {
        STEAM_FORCE_DESKTOPUI_SCALING = "0.625";
        # SteamVR bundles Qt5 with only the XCB platform plugin. The global
        # Wayland fallback value is interpreted literally by that runtime.
        QT_QPA_PLATFORM = "xcb";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        __NV_PRIME_RENDER_OFFLOAD = "1";
        __VK_LAYER_NV_optimus = "NVIDIA_only";
      };
    };
    fontPackages = with pkgs; [source-han-sans];
    extraPackages = with pkgs; [
      corefonts
      noto-fonts-cjk-sans
      source-han-sans
      # SteamVR's native monitor is a Qt5 application, and its vrserver also
      # needs host PipeWire/GBM/XKB libraries that the stock runtime lacks.
      qt5.qtbase
      qt5.qtmultimedia
      qt5.qtwayland
      libdrm
      libgbm
      pulseaudio
      pipewire
      libcap
      procps
      xkeyboard-config
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
