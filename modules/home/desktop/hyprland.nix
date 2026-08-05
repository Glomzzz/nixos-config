{
  config,
  inputs,
  pkgs,
  ...
}: let
  hyprlandPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
  grimblast = pkgs.grimblast.override {hyprland = hyprlandPackage;};
  hyprlandOnly = ''${pkgs.systemd}/lib/systemd/systemd-xdg-autostart-condition "Hyprland" ""'';
  wallpaper = ../../../assets/e022.jpg;
  batteryStatus = pkgs.writeShellApplication {
    name = "waybar-battery-status";
    runtimeInputs = [
      pkgs.jq
      pkgs.power-profiles-daemon
    ];
    text = ''
      battery_path=""
      for supply in /sys/class/power_supply/BAT*; do
        if [[ -r "$supply/capacity" && -r "$supply/status" ]]; then
          battery_path="$supply"
          break
        fi
      done

      if [[ -z "$battery_path" ]]; then
        jq --null-input --compact-output \
          --arg text "BAT --" \
          --arg tooltip "Battery not found" \
          '{text: $text, tooltip: $tooltip, class: "unavailable"}'
        exit 0
      fi

      read -r capacity < "$battery_path/capacity"
      read -r status < "$battery_path/status"
      profile="$(powerprofilesctl get 2>/dev/null || true)"

      case "$profile" in
        power-saver)
          profile_label="Power saver"
          next_label="balanced"
          ;;
        balanced)
          profile_label="Balanced"
          next_label="performance"
          ;;
        performance)
          profile_label="Performance"
          next_label="power saver"
          ;;
        *)
          profile="balanced"
          profile_label="Balanced"
          next_label="performance"
          ;;
      esac

      case "$status" in
        Charging)
          suffix=" +"
          ;;
        Full|"Not charging")
          suffix=" AC"
          ;;
        *)
          suffix=""
          ;;
      esac

      tooltip="$(printf 'Battery: %s%% (%s)\nPower profile: %s\nClick to switch to %s' "$capacity" "$status" "$profile_label" "$next_label")"
      jq --null-input --compact-output \
        --arg text "BAT $capacity%$suffix" \
        --arg tooltip "$tooltip" \
        --arg class "$profile" \
        '{text: $text, tooltip: $tooltip, class: $class}'
    '';
  };
  cyclePowerProfile = pkgs.writeShellApplication {
    name = "waybar-cycle-power-profile";
    runtimeInputs = [pkgs.power-profiles-daemon];
    text = ''
      case "$(powerprofilesctl get)" in
        power-saver)
          next="balanced"
          ;;
        balanced)
          next="performance"
          ;;
        *)
          next="power-saver"
          ;;
      esac

      powerprofilesctl set "$next"
    '';
  };
  setX11Primary = pkgs.writeShellApplication {
    name = "set-x11-primary";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.xrandr
    ];
    text = ''
      for _ in {1..20}; do
        if xrandr --output eDP-1 --primary 2>/dev/null; then
          exit 0
        fi
        sleep 0.25
      done

      echo "eDP-1 did not become available to XWayland" >&2
      exit 1
    '';
  };
in {
  home.packages = [
    pkgs.brightnessctl
    grimblast
    pkgs.wl-clipboard
  ];

  xdg.configFile = {
    "uwsm/env".source = "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
    "uwsm/env-hyprland".text = ''
      export XCURSOR_SIZE=24
      export HYPRCURSOR_SIZE=24
    '';
  };

  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";
    package = null;
    portalPackage = null;
    systemd.enable = false;

    extraConfig = ''
      local mainMod = "SUPER"
      local terminal = "${pkgs.uwsm}/bin/uwsm app -- ${pkgs.kitty}/bin/kitty"
      local editor = "${pkgs.uwsm}/bin/uwsm app -- ${pkgs.emacs-pgtk}/bin/emacsclient -c -a ${pkgs.emacs-pgtk}/bin/emacs"
      local fileManager = "${pkgs.uwsm}/bin/uwsm app -- ${pkgs.kdePackages.dolphin}/bin/dolphin"
      local menu = "${pkgs.uwsm}/bin/uwsm app -- ${pkgs.fuzzel}/bin/fuzzel"
      local clipboard = "${pkgs.cliphist}/bin/cliphist list | ${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt 'Clipboard> ' | ${pkgs.cliphist}/bin/cliphist decode | ${pkgs.wl-clipboard}/bin/wl-copy"

      local function markLaptopAsX11Primary()
        hl.exec_cmd("${setX11Primary}/bin/set-x11-primary")
      end

      hl.on("hyprland.start", markLaptopAsX11Primary)
      hl.on("monitor.added", markLaptopAsX11Primary)

      hl.monitor({
        output = "eDP-1",
        mode = "2560x1600@240",
        position = "0x0",
        scale = 1.6,
      })

      hl.monitor({
        output = "HDMI-A-1",
        mode = "1920x1080@60",
        position = "1600x0",
        scale = 1,
      })

      hl.monitor({
        output = "",
        mode = "preferred",
        position = "auto",
        scale = "auto",
      })

      hl.workspace_rule({
        workspace = "1",
        monitor = "eDP-1",
        default = true,
      })

      hl.workspace_rule({
        workspace = "2",
        monitor = "HDMI-A-1",
        default = true,
      })

      hl.config({
        general = {
          gaps_in = 5,
          gaps_out = 10,
          border_size = 2,
          col = {
            active_border = "rgba(89dcebff)",
            inactive_border = "rgba(585b70aa)",
          },
          resize_on_border = true,
          allow_tearing = false,
          layout = "dwindle",
        },

        decoration = {
          rounding = 6,
          active_opacity = 1.0,
          inactive_opacity = 0.96,
          shadow = {
            enabled = true,
            range = 8,
            render_power = 3,
            color = 0x99000000,
          },
          blur = {
            enabled = true,
            size = 6,
            passes = 2,
            vibrancy = 0.15,
          },
        },

        animations = {
          enabled = true,
        },

        input = {
          kb_layout = "us",
          kb_options = "ctrl:nocaps",
          follow_mouse = 1,
          sensitivity = 0,
          accel_profile = "flat",
          touchpad = {
            natural_scroll = true,
          },
        },

        cursor = {
          default_monitor = "eDP-1",
        },

        dwindle = {
          preserve_split = true,
        },

        misc = {
          disable_hyprland_logo = true,
          force_default_wallpaper = 0,
        },

        xwayland = {
          -- Keep legacy X11 buffers at native resolution. X11-only apps must
          -- set their own toolkit scale instead of being enlarged and blurred.
          force_zero_scaling = true,
        },
      })

      hl.gesture({
        fingers = 3,
        direction = "horizontal",
        action = "workspace",
      })

      hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
      hl.bind(mainMod .. " + C", hl.dsp.exec_cmd(editor))
      hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
      hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(menu))
      hl.bind(mainMod .. " + V", hl.dsp.exec_cmd(clipboard))
      hl.bind(mainMod .. " + Q", hl.dsp.window.close())
      hl.bind(mainMod .. " + T", hl.dsp.window.float({ action = "toggle" }))
      hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
      hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("${pkgs.uwsm}/bin/uwsm stop"))

      hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
      hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
      hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
      hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

      hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
      hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
      hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
      hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))

      hl.bind(mainMod .. " + CTRL + left", hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true })
      hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }), { repeating = true })
      hl.bind(mainMod .. " + CTRL + up", hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true })
      hl.bind(mainMod .. " + CTRL + down", hl.dsp.window.resize({ x = 0, y = 40, relative = true }), { repeating = true })

      for i = 1, 10 do
        local key = i % 10
        hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = tostring(i) }))
        hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = tostring(i) }))
      end

      hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
      hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
      hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
      hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

      hl.bind("Print", hl.dsp.exec_cmd("${grimblast}/bin/grimblast copy screen"))
      hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("${grimblast}/bin/grimblast copy output"))
      hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("${grimblast}/bin/grimblast copy area"))

      hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("${pkgs.wireplumber}/bin/wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
      hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
      hl.bind("XF86AudioMute", hl.dsp.exec_cmd("${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
      hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
      hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("${pkgs.brightnessctl}/bin/brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
      hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("${pkgs.brightnessctl}/bin/brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
      hl.bind("XF86AudioNext", hl.dsp.exec_cmd("${pkgs.playerctl}/bin/playerctl next"), { locked = true })
      hl.bind("XF86AudioPause", hl.dsp.exec_cmd("${pkgs.playerctl}/bin/playerctl play-pause"), { locked = true })
      hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("${pkgs.playerctl}/bin/playerctl play-pause"), { locked = true })
      hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("${pkgs.playerctl}/bin/playerctl previous"), { locked = true })

      hl.window_rule({
        name = "suppress-maximize-events",
        match = { class = ".*" },
        suppress_event = "maximize",
      })

      hl.window_rule({
        name = "fix-xwayland-drags",
        match = {
          class = "^$",
          title = "^$",
          xwayland = true,
          float = true,
          fullscreen = false,
          pin = false,
        },
        no_focus = true,
      })
    '';
  };

  programs = {
    fuzzel = {
      enable = true;
      settings = {
        main = {
          terminal = "${pkgs.kitty}/bin/kitty";
          launch-prefix = "${pkgs.uwsm}/bin/uwsm app --";
          layer = "overlay";
          font = "JetBrainsMono Nerd Font:size=13";
          width = 50;
          lines = 12;
          horizontal-pad = 16;
          vertical-pad = 12;
          inner-pad = 8;
        };
        colors = {
          background = "11111bee";
          text = "cdd6f4ff";
          prompt = "89dcebff";
          placeholder = "6c7086ff";
          input = "f5e0dcff";
          match = "f9e2afff";
          selection = "313244ff";
          selection-text = "cdd6f4ff";
          selection-match = "fab387ff";
          counter = "a6adc8ff";
          border = "89dcebff";
        };
        border = {
          width = 2;
          radius = 4;
        };
      };
    };

    waybar = {
      enable = true;
      systemd.enable = true;
      settings.mainBar = {
        layer = "top";
        position = "top";
        height = 34;
        spacing = 4;
        modules-left = [
          "hyprland/workspaces"
          "hyprland/window"
        ];
        modules-center = ["clock"];
        modules-right = [
          "tray"
          "pulseaudio"
          "cpu"
          # "network"
          "memory"
          "backlight"
          "custom/battery"
        ];

        "hyprland/workspaces" = {
          format = "{name}";
          on-click = "activate";
          sort-by-number = true;
          persistent-workspaces."*" = [
            1
            2
            3
            4
            5
          ];
        };
        "hyprland/window" = {
          max-length = 70;
          separate-outputs = true;
        };
        tray.spacing = 8;
        pulseaudio = {
          format = "VOL {volume}%";
          format-muted = "VOL muted";
          on-click = "${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        };
        network = {
          interval = 1;
          format = "NET ↑ {bandwidthUpBits} ↓ {bandwidthDownBits}";
          format-wifi = "NET ↑ {bandwidthUpBits} ↓ {bandwidthDownBits}";
          format-ethernet = "NET ↑ {bandwidthUpBits} ↓ {bandwidthDownBits}";
          format-linked = "NET linked";
          format-disconnected = "NET --";
          format-disabled = "NET off";
          max-length = 32;
          tooltip-format-wifi = "{essid}\nSignal: {signalStrength}%\nAddress: {ipaddr}/{cidr}";
          tooltip-format-ethernet = "{ifname}\nAddress: {ipaddr}/{cidr}";
          tooltip-format-disconnected = "Network disconnected";
          tooltip-format-disabled = "Network disabled";
        };
        backlight = {
          device = "nvidia_0";
          format = "BRT {percent}%";
          on-scroll-up = "${pkgs.brightnessctl}/bin/brightnessctl -d nvidia_0 -e4 -n2 set 5%+";
          on-scroll-down = "${pkgs.brightnessctl}/bin/brightnessctl -d nvidia_0 -e4 -n2 set 5%-";
        };
        cpu = {
          format = "CPU {usage}%";
          interval = 5;
        };
        memory = {
          format = "MEM {percentage}%";
          interval = 5;
        };
        "custom/battery" = {
          exec = "${batteryStatus}/bin/waybar-battery-status";
          exec-on-event = true;
          interval = 5;
          on-click = "${cyclePowerProfile}/bin/waybar-cycle-power-profile";
          return-type = "json";
        };
        clock = {
          format = "{:%a %d %b  %H:%M}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
        };
      };

      style = ''
        * {
          border: none;
          border-radius: 0;
          min-height: 0;
          font-family: "JetBrainsMono Nerd Font";
          font-size: 13px;
        }

        window#waybar {
          background: rgba(17, 17, 27, 0.94);
          color: #cdd6f4;
        }

        #workspaces button {
          padding: 0 9px;
          color: #a6adc8;
          background: transparent;
          border-bottom: 2px solid transparent;
        }

        #workspaces button.active {
          color: #89dceb;
          border-bottom-color: #89dceb;
        }

        #workspaces button.urgent {
          color: #11111b;
          background: #f38ba8;
        }

        #window,
        #tray,
        #pulseaudio,
        #network,
        #backlight,
        #cpu,
        #memory,
        #custom-battery,
        #clock {
          padding: 0 8px;
        }

        #clock {
          color: #fab387;
          font-weight: 600;
        }

        #network.disconnected,
        #pulseaudio.muted {
          color: #f38ba8;
        }

        #backlight {
          color: #f9e2af;
        }

        #custom-battery.performance {
          color: #fab387;
        }

        #custom-battery.balanced {
          color: #89dceb;
        }

        #custom-battery.power-saver {
          color: #a6e3a1;
        }

        tooltip {
          background: #1e1e2e;
          color: #cdd6f4;
          border: 1px solid #45475a;
          border-radius: 4px;
        }
      '';
    };
  };

  services = {
    cliphist = {
      enable = true;
      allowImages = true;
    };

    hyprpaper = {
      enable = true;
      settings = {
        ipc = true;
        splash = false;
        wallpaper = {
          monitor = "";
          path = "${wallpaper}";
          fit_mode = "cover";
        };
      };
    };

    hyprpolkitagent.enable = true;

    mako = {
      enable = true;
      settings = {
        anchor = "top-right";
        background-color = "#1e1e2e";
        border-color = "#89dceb";
        border-radius = 6;
        border-size = 2;
        default-timeout = 5000;
        font = "JetBrainsMono Nerd Font 11";
        height = 120;
        icons = true;
        layer = "overlay";
        margin = 10;
        markup = true;
        max-icon-size = 48;
        padding = 12;
        text-color = "#cdd6f4";
        width = 360;

        "urgency=low".border-color = "#a6e3a1";
        "urgency=critical" = {
          background-color = "#3b1f2b";
          border-color = "#f38ba8";
          default-timeout = 0;
        };
      };
    };
  };

  systemd.user.services = {
    mako = {
      Unit = {
        Description = "Lightweight Wayland notification daemon";
        Documentation = "https://github.com/emersion/mako";
        PartOf = ["graphical-session.target"];
        After = ["graphical-session.target"];
      };
      Service = {
        Type = "dbus";
        BusName = "org.freedesktop.Notifications";
        ExecCondition = hyprlandOnly;
        ExecStart = "${pkgs.mako}/bin/mako";
        ExecReload = "${pkgs.mako}/bin/makoctl reload";
        Slice = "background-graphical.slice";
      };
      Install.WantedBy = ["graphical-session.target"];
    };
    waybar.Service = {
      ExecCondition = hyprlandOnly;
      Slice = "app-graphical.slice";
    };
    hyprpaper.Service = {
      ExecCondition = hyprlandOnly;
      Slice = "background-graphical.slice";
    };
    hyprpolkitagent.Service = {
      ExecCondition = hyprlandOnly;
      Slice = "session-graphical.slice";
    };
    cliphist.Service = {
      ExecCondition = hyprlandOnly;
      Slice = "background-graphical.slice";
    };
    cliphist-images.Service = {
      ExecCondition = hyprlandOnly;
      Slice = "background-graphical.slice";
    };
  };
}
