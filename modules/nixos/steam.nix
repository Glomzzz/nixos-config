{pkgs, ...}: let
  # Use `steam-game-laptop %command%` as a game's Steam launch option when it
  # needs an isolated native-resolution surface on the laptop panel.
  steamGameLaptop = pkgs.writeShellApplication {
    name = "steam-game-laptop";
    text = ''
      # Let the Wayland backend convert Niri's 1707x1067 fullscreen configure
      # through the output's 1.5 fractional scale. This produces a 2560x1600
      # physical outer buffer and keeps absolute pointer coordinates aligned.
      # Use the unwrapped binary because Steam's pressure-vessel sandbox cannot
      # inherit the capabilities on NixOS's set-capability Gamescope wrapper.
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
    steamGameLaptop
  ];

  programs = {
    gamemode.enable = true;

    gamescope = {
      enable = true;
      capSysNice = true;
    };

    steam = {
      enable = true;
      package = pkgs.steam.override {
        # Steam's Xwayland helper measures this panel as a 1.6x desktop DPI
        # factor. Use its reciprocal so one CEF CSS pixel maps to one physical
        # pixel instead of enlarging the entire client UI.
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
    };
  };
}
