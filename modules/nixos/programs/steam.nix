{pkgs, ...}: let
  # Use `steam-game-laptop %command%` as a game's Steam launch option when it
  # needs a fullscreen surface sized for the laptop panel. Dota 2 runs directly
  # on the desktop Xwayland display for Fcitx; other games use Gamescope.
  steamGameLaptop = pkgs.writeShellApplication {
    name = "steam-game-laptop";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
      pkgs.jq
    ];
    text = ''
      # Older system generations exported an NVIDIA ICD filename that no
      # longer exists. Drop only that stale override so an already-running
      # desktop session can still start Gamescope after switching generations.
      if [[ -n "''${VK_DRIVER_FILES:-}" && ! -e "''${VK_DRIVER_FILES}" ]]; then
        unset VK_DRIVER_FILES
      fi

      # 16:9-only titles (Just Go, Overcooked! 2): match the game's render
      # surface to its highest supported mode so Unity, Gamescope, and
      # absolute input use the same coordinates; Gamescope letterboxes it on
      # the 16:10 panel.
      #
      # How to Fish (Unity 6) instead reads the satellite's DPI-virtualized
      # desktop - 3840x2400, i.e. 2560x1600 at the 1.5 base scale - as its
      # native mode, so its fullscreen surface overflows the logical screen
      # and the game starts blown up to 1.5x. Pin its render surface to the
      # panel's native mode instead.
      case "''${SteamAppId:-''${STEAM_COMPAT_APP_ID:-}}" in
        570)
          # Gamescope's private display separates Dota from the desktop IME
          # and its candidate windows. Use the satellite display where Fcitx
          # is already connected, not a second daemon inside Gamescope.
          # Both SDL2's and SDL3's driver hints are scoped to Dota here; SDL3
          # otherwise prefers Wayland's text-input path over the Fcitx module.
          export SDL_IM_MODULE=fcitx
          export XMODIFIERS=@im=fcitx
          export SDL_VIDEODRIVER=x11
          export SDL_VIDEO_DRIVER=x11

          # Compositor scaling now exposes 2560x1600 on the satellite too.
          # Retain the saved native mode rather than restoring the old logical
          # resolution when removing the nested compositor.
          dotaUserdata="''${XDG_DATA_HOME:-$HOME/.local/share}/Steam/userdata"
          for dotaVideo in "$dotaUserdata"/*/570/local/cfg/video.txt; do
            [[ -f "$dotaVideo" ]] || continue
            dotaVideoTmp=$(mktemp --tmpdir="$(dirname "$dotaVideo")" .video.txt.XXXXXX)
            trap 'rm -f "$dotaVideoTmp"' EXIT
            if sed -E \
              -e 's/("setting\.defaultres"[[:space:]]+)"[^"]*"/\1"2560"/' \
              -e 's/("setting\.defaultresheight"[[:space:]]+)"[^"]*"/\1"1600"/' \
              -e 's/("setting\.fullscreen"[[:space:]]+)"[^"]*"/\1"1"/' \
              -e 's/("setting\.nowindowborder"[[:space:]]+)"[^"]*"/\1"0"/' \
              "$dotaVideo" > "$dotaVideoTmp"; then
              mv "$dotaVideoTmp" "$dotaVideo"
            else
              rm -f "$dotaVideoTmp"
              echo "steam-game-laptop: could not update Dota 2 video.txt; continuing" >&2
            fi
            trap - EXIT
          done
          # Also cover first launches where video.txt has not been written.
          exec "$@" -w 2560 -h 1600 -fullscreen
          ;;
        379430)
          # KCD's CryEngine launcher defaults to 1280x720 under Proton even
          # when Gamescope exposes the panel's native mode.
          set -- "$@" \
            -r_width 2560 \
            -r_height 1600 \
            -r_fullscreen 1
          ;;
        1862520|728880)
          set -- "$@" \
            -screen-width 2560 \
            -screen-height 1440 \
            -screen-fullscreen 1
          ;;
        4001890)
          set -- "$@" \
            -screen-width 2560 \
            -screen-height 1600 \
            -screen-fullscreen 1
          ;;
        105600)
          # Terraria persists Xwayland's DPI-scaled desktop (3840x2400) in
          # config.json. Keep the saved mode at the panel's physical 2K mode;
          # Gamescope supplies the same mode to the game at runtime.
          terrariaConfig="''${XDG_DATA_HOME:-$HOME/.local/share}/Terraria/config.json"
          if [[ -f "$terrariaConfig" ]]; then
            terrariaConfigTmp=$(mktemp --tmpdir="$(dirname "$terrariaConfig")" .config.json.XXXXXX)
            trap 'rm -f "$terrariaConfigTmp"' EXIT
            if jq \
              '.DisplayWidth = 2560 | .DisplayHeight = 1600 | .Fullscreen = true | .WindowBorderless = true' \
              "$terrariaConfig" > "$terrariaConfigTmp"; then
              mv "$terrariaConfigTmp" "$terrariaConfig"
            else
              rm -f "$terrariaConfigTmp"
              echo "steam-game-laptop: could not update Terraria config; continuing" >&2
            fi
            trap - EXIT
          fi
          ;;
      esac

      # Niri presents eDP-1 as 1707x1066 logical pixels at scale 1.5. Let the
      # Wayland backend negotiate that outer surface while the nested game
      # remains at the panel's native 2560x1600 pixels. KCD currently trips a
      # Gamescope input-thread abort with forced cursor grabbing, so leave that
      # option off for KCD while retaining it for the other adopted games.
      gamescopeArgs=(
        --backend wayland
        --fullscreen
        --nested-width 2560
        --nested-height 1600
        --nested-refresh 240
        --nested-unfocused-refresh 60
        --force-windows-fullscreen
        --adaptive-sync
      )
      if [[ "''${SteamAppId:-''${STEAM_COMPAT_APP_ID:-}}" != 379430 ]]; then
        gamescopeArgs+=(--force-grab-cursor)
      fi
      exec ${pkgs.gamescope}/bin/gamescope "''${gamescopeArgs[@]}" -- "$@"
    '';
  };

  # Steam dropped STEAM_FORCE_DESKTOPUI_SCALING and the -forcedesktopscaling
  # switch (neither name survives in the 2026 client binaries). The desktop UI
  # scale is now the persisted `Accessibility/DesktopUIScale` value in
  # config.vdf, and Steam's dimension-based auto scale for this panel works out
  # to 1.0 - one CEF CSS pixel per physical pixel, i.e. 1/1.5 of every native
  # Wayland client on Niri's 1.5x output. Seed that value to 1.5 before each
  # start; the client reads it once at startup and writes the same value back
  # on exit, so a single successful start keeps it in place.
  steamWithUiScale = steam: let
    seedSteamUiScale = pkgs.writeShellApplication {
      name = "steam-ui-scale";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.gnused
      ];
      text = ''
        uiScale=1.5
        config="''${XDG_DATA_HOME:-$HOME/.local/share}/Steam/config/config.vdf"
        configDir="$(dirname "$config")"
        mkdir -p "$configDir"
        configTmp=$(mktemp --tmpdir="$configDir" .config.vdf.XXXXXX)
        trap 'rm -f "$configTmp"' EXIT

        if [[ -s "$config" ]]; then
          if grep -q '"DesktopUIScale"' "$config"; then
            sed -E "s/(\"DesktopUIScale\"[[:space:]]+)\"[^\"]*\"/\\1\"$uiScale\"/" "$config" > "$configTmp"
          else
            # config.vdf keeps its top-level closing brace on the last line.
            head -n -1 "$config" > "$configTmp"
            printf '\t"Accessibility"\n\t{\n\t\t"DesktopUIScale"\t\t"%s"\n\t}\n' "$uiScale" >> "$configTmp"
            tail -n 1 "$config" >> "$configTmp"
          fi
        else
          # First run: hand Steam a client config whose only setting is the UI
          # scale; it merges its own defaults in at startup.
          printf '"Accessibility"\n{\n\t"DesktopUIScale"\t\t"%s"\n}\n' "$uiScale" > "$configTmp"
        fi

        mv "$configTmp" "$config"
        trap - EXIT
        exec ${steam}/bin/steam "$@"
      '';
    };
  in
    # programs.steam.package is run through an `apply` that calls `.override`,
    # so the wrapper has to forward that to the Steam package it wraps instead
    # of hiding it.
    pkgs.symlinkJoin {
      name = "steam";
      paths = [steam];
      postBuild = ''
        rm -f $out/bin/steam
        ln -s ${seedSteamUiScale}/bin/steam-ui-scale $out/bin/steam
      '';
      passthru =
        # The module adds `steam-run` from this same option, and it goes through
        # an `apply` that calls `.override` with the system's extra libraries
        # and packages, so both have to be forwarded rather than hidden by the
        # wrapper. `run` only needs the FHS environment, which is unchanged.
        {inherit (steam) run run-free;}
        // {
          override = f: steamWithUiScale (steam.override f);
        };
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
    # steamWithUiScale seeds the 1.5x desktop UI scale described above; the
    # nested override carries the arguments the module's `apply` extends.
    package = steamWithUiScale (pkgs.steam.override {
      # Do not pass -pipewire: it routes Steam's desktop/Remote Play capture
      # into the PipeWire+EGL pipeline that cannot initialize on NVIDIA
      # Wayland hosts (Steam logs "CDesktopCapturePipeWire: Couldn't initialize
      # EGL: 0x3001"; upstream valve-software/steam-for-linux#10315/#11913),
      # and the ALVR use case it was added for is gone.
      extraArgs = "";
      # SteamVR and every game launched by Steam must select the NVIDIA GPU.
      extraEnv = {
        # SteamVR bundles Qt5 with only the XCB platform plugin. The global
        # Wayland fallback value is interpreted literally by that runtime.
        QT_QPA_PLATFORM = "xcb";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        __NV_PRIME_RENDER_OFFLOAD = "1";
        __VK_LAYER_NV_optimus = "NVIDIA_only";
      };
    });
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
