{pkgs, ...}: let
  # Use `steam-game-laptop %command%` as a game's Steam launch option when it
  # needs Gamescope to enforce the laptop panel's native fullscreen geometry.
  steamGameLaptop = pkgs.writeShellApplication {
    name = "steam-game-laptop";
    text = ''
      # Niri presents eDP-1 as 1707x1067 logical pixels at scale 1.5. Keep
      # Gamescope's outer SDL surface in that space while the nested game
      # surface stays at the panel's native 2560x1600 pixels.
      exec ${pkgs.gamemode}/bin/gamemoderun \
        /run/wrappers/bin/gamescope \
        --backend sdl \
        --fullscreen \
        --output-width 1707 \
        --output-height 1067 \
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
