{self}: {
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.clavis-shell;
  defaultPackage = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
  niriConfig = ../config/niri/config.kdl;
  sessionVariables =
    {
      _JAVA_AWT_WM_NONREPARENTING = "1";
    }
    // lib.optionalAttrs cfg.xwaylandSatellite.enable {
      XWAYLAND_SATELLITE_BASE_SCALE = toString cfg.xwaylandSatellite.baseScale;
    };
in {
  options.services.clavis-shell = {
    enable = lib.mkEnableOption "Clavis Shell and its Niri configuration";

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      defaultText = lib.literalExpression "niri-config.packages.\${pkgs.system}.default";
      description = "Wrapped Clavis Shell package to run.";
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      default = niriConfig;
      description = "Niri configuration installed as config.kdl.";
    };

    defaultWallpaper = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Wallpaper used on first start when no personalization file exists.";
    };

    language = lib.mkOption {
      type = lib.types.enum ["en_US"];
      default = "en_US";
      description = "English display language enforced for Clavis Shell.";
    };

    primaryOutput = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Output preferred before Niri reports a focused output.";
    };

    enableClipboard =
      lib.mkEnableOption "the Clavis MIME-aware clipboard watcher"
      // {
        default = true;
      };

    xwaylandSatellite = {
      enable =
        lib.mkEnableOption "Niri's Xwayland Satellite integration"
        // {
          default = true;
        };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.xwayland-satellite;
        defaultText = lib.literalExpression "pkgs.xwayland-satellite";
        description = "Xwayland Satellite package exposed to Niri.";
      };

      baseScale = lib.mkOption {
        type = lib.types.number;
        default = 1.5;
        description = "Base scale used for X11 clients on mixed-DPI outputs.";
      };
    };

    extraPackages = lib.mkOption {
      type = with lib.types; listOf package;
      default = with pkgs; [
        brightnessctl
        emacs-pgtk
        kdePackages.dolphin
        kitty
        playerctl
        wireplumber
      ];
      defaultText = lib.literalExpression "common launcher and media-control packages";
      description = "Packages made available to Niri key bindings.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.xwaylandSatellite.enable || cfg.xwaylandSatellite.baseScale > 0;
        message = "services.clavis-shell.xwaylandSatellite.baseScale must be positive";
      }
    ];

    home.packages =
      [cfg.package]
      ++ cfg.extraPackages
      ++ lib.optional cfg.xwaylandSatellite.enable cfg.xwaylandSatellite.package;

    # SDDM starts Niri through the systemd user manager, which does not source
    # hm-session-vars.sh. Keep both environments aligned for GUI and shell apps.
    home.sessionVariables = sessionVariables;
    systemd.user.sessionVariables = sessionVariables;

    xdg.configFile."niri/config.kdl" = {
      source = cfg.configFile;
      force = true;
    };

    xdg.configFile."niri/xwayland-satellite.kdl" = {
      text =
        if cfg.xwaylandSatellite.enable
        then ''
          xwayland-satellite {
              path "${cfg.xwaylandSatellite.package}/bin/xwayland-satellite"
          }
        ''
        else ''
          xwayland-satellite {
              off
          }
        '';
    };

    systemd.user.services = {
      clavis-shell = {
        Unit = {
          Description = "Clavis Quickshell desktop shell";
          Documentation = "https://github.com/StatIndet/quickshell";
          PartOf = ["graphical-session.target"];
          After = ["graphical-session.target"];
          Requisite = ["graphical-session.target"];
        };
        Service = {
          Environment =
            ["CLAVIS_LANGUAGE=${cfg.language}"]
            ++ lib.optional (cfg.defaultWallpaper != null)
            "CLAVIS_DEFAULT_WALLPAPER=${toString cfg.defaultWallpaper}"
            ++ lib.optional (cfg.primaryOutput != null)
            "CLAVIS_PRIMARY_OUTPUT=${cfg.primaryOutput}";
          ExecStart = "${cfg.package}/bin/qs --no-duplicate";
          Restart = "on-failure";
          RestartSec = 2;
          Slice = "app-graphical.slice";
        };
        Install.WantedBy = ["niri.service"];
      };

      clavis-cliphist = lib.mkIf cfg.enableClipboard {
        Unit = {
          Description = "Clavis MIME-aware clipboard history watcher";
          PartOf = ["graphical-session.target"];
          After = ["graphical-session.target"];
          Requisite = ["graphical-session.target"];
        };
        Service = {
          Environment = "PATH=${lib.makeBinPath [
            cfg.package
            pkgs.cliphist
            pkgs.coreutils
            pkgs.systemd
            pkgs.wl-clipboard
          ]}";
          ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${cfg.package}/bin/key clipboard store";
          Restart = "on-failure";
          RestartSec = 1;
          Slice = "background-graphical.slice";
        };
        Install.WantedBy = ["niri.service"];
      };
    };
  };
}
