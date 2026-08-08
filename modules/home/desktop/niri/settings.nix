{pkgs, ...}: let
  terminal = "${pkgs.foot}/bin/foot";
  launcher = "${pkgs.fuzzel}/bin/fuzzel";
  filemanager = "${terminal} -e ${pkgs.yazi}/bin/yazi";
  # No emacs daemon runs in this session (see programs/dev/editor/emacs.nix),
  # so this launches a standalone frame rather than emacsclient.
  editor = "${pkgs.emacs-pgtk}/bin/emacs";
  locker = "${pkgs.swaylock}/bin/swaylock";
  brightness = "${pkgs.brightnessctl}/bin/brightnessctl";
  playerctl = "${pkgs.playerctl}/bin/playerctl";
  wpctl = "${pkgs.wireplumber}/bin/wpctl";
in {
  # Option names here mirror niri's KDL nodes exactly (kebab-case). Actions use
  # the `binds.<key>.action.<action-name>` form; niri-flake's
  # `config.lib.niri.actions` helper is deprecated upstream and does not cover
  # every action, so it is deliberately unused.
  programs.niri.settings = {
    prefer-no-csd = true;
    screenshot-path = "~/Pictures/Screenshots/%Y-%m-%dT%H-%M-%S.png";

    hotkey-overlay.skip-at-startup = true;

    input = {
      keyboard.xkb = {
        layout = "us";
        # Caps Lock acts as a second Ctrl, with no Caps Lock left on the board.
        # niri reads xkb directly from libxkbcommon, so the NixOS-side
        # services.xserver.xkb options do not reach this session; they only
        # cover the consoles/greeter.
        options = "ctrl:nocaps";
      };

      touchpad = {
        tap = true;
        natural-scroll = true;
        dwt = true;
        click-method = "clickfinger";
        accel-profile = "adaptive";
      };

      mouse = {
        # Matches services.libinput.mouse.accelProfile = "flat" set on the
        # NixOS side, so pointer feel does not change between sessions.
        accel-profile = "flat";
        natural-scroll = false;
      };

      # Pointer stays put unless deliberately moved; focus follows keys.
      focus-follows-mouse.enable = false;
      warp-mouse-to-focus.enable = false;
      workspace-auto-back-and-forth = true;
    };

    # niri has no X11-style "primary output" flag. The two things that decide
    # which screen behaves as primary are where each output sits in the global
    # coordinate space and which one takes focus at startup, so both are pinned
    # to the laptop panel. Without this niri places outputs automatically and
    # sorts by name, which puts HDMI-A-1 at the origin and hands it the initial
    # focus whenever the dock is attached.
    outputs = {
      # 2560x1600 at the auto-picked scale 1.5 is 1706.67 logical pixels wide,
      # so the external monitor starts at x=1707 to sit flush to its right.
      # x=1706 would overlap the panel by a fraction of a pixel, and niri
      # responds to any overlap by discarding both explicit positions and
      # auto-placing instead. Keep this in step if the panel scale changes.
      "eDP-1" = {
        focus-at-startup = true;
        position = {
          x = 0;
          y = 0;
        };
      };
      "HDMI-A-1".position = {
        x = 1707;
        y = 0;
      };
    };

    layout = {
      gaps = 8;
      center-focused-column = "never";

      preset-column-widths = [
        {proportion = 1.0 / 3.0;}
        {proportion = 1.0 / 2.0;}
        {proportion = 2.0 / 3.0;}
      ];
      default-column-width.proportion = 1.0 / 2.0;

      focus-ring = {
        enable = true;
        width = 2;
        active.color = "#89b4fa";
        inactive.color = "#45475a";
      };

      border.enable = false;

      shadow = {
        enable = true;
        softness = 20;
        spread = 3;
        offset = {
          x = 0;
          y = 3;
        };
        color = "#00000060";
      };

      # Leaves room for the waybar instance configured in waybar.nix.
      struts = {
        left = 4;
        right = 4;
        top = 0;
        bottom = 0;
      };

      tab-indicator = {
        enable = true;
        position = "left";
        gaps-between-tabs = 4;
      };
    };

    cursor = {
      theme = "Adwaita";
      size = 24;
      hide-when-typing = true;
    };

    # Only session-specific variables belong here. The Wayland toolkit hints
    # (NIXOS_OZONE_WL, QT_QPA_PLATFORM, MOZ_ENABLE_WAYLAND, SDL_VIDEODRIVER)
    # are set system-wide in hardware/zephyrus/gpu, and niri-session re-execs
    # as a login shell, so /etc/profile already exports them to everything niri
    # spawns. Repeating them here would just be two places to keep in sync.
    environment = {
      # Xwayland apps launched by niri find the satellite display here.
      DISPLAY = ":0";
    };

    # niri has no XDG-autostart handling of its own, so anything that must be
    # running for the session to feel complete is spawned explicitly.
    # Wallpaper, clipboard, notifications and idle locking are systemd user
    # services instead (see the sibling modules).
    spawn-at-startup = [
      {argv = ["${pkgs.xwayland-satellite}/bin/xwayland-satellite"];}
      # fcitx5 previously came up via KDE's autostart; niri has no XDG-autostart
      # handling, so without this Chinese input silently stops working.
      # Deliberately unqualified: the i18n.inputMethod module builds its own
      # fcitx5 with the rime addons and puts it on PATH. A store path to
      # pkgs.fcitx5-with-addons would launch an addon-less build instead.
      {argv = ["fcitx5" "-d" "--replace"];}
    ];

    binds = {
      # --- launching -------------------------------------------------------
      "Mod+Slash".action.spawn = terminal;
      "Mod+Return".action.spawn = editor;
      "Mod+D".action.spawn = launcher;
      "Mod+E".action.spawn = ["sh" "-c" filemanager];
      "Mod+Escape".action.spawn = locker;
      # Picker script defined in clipboard.nix.
      "Mod+Shift+C".action.spawn = "clipboard-history";

      # --- window management ----------------------------------------------
      "Mod+Q".action.close-window = [];
      "Mod+F".action.maximize-column = [];
      "Mod+Shift+F".action.fullscreen-window = [];
      "Mod+V".action.toggle-window-floating = [];
      "Mod+W".action.toggle-column-tabbed-display = [];
      "Mod+C".action.center-column = [];

      # --- focus -----------------------------------------------------------
      "Mod+Left".action.focus-column-left = [];
      "Mod+Right".action.focus-column-right = [];
      "Mod+Up".action.focus-window-up = [];
      "Mod+Down".action.focus-window-down = [];
      "Mod+H".action.focus-column-left = [];
      "Mod+L".action.focus-column-right = [];
      "Mod+K".action.focus-window-up = [];
      "Mod+J".action.focus-window-down = [];

      # --- moving ----------------------------------------------------------
      "Mod+Shift+Left".action.move-column-left = [];
      "Mod+Shift+Right".action.move-column-right = [];
      "Mod+Shift+Up".action.move-window-up = [];
      "Mod+Shift+Down".action.move-window-down = [];

      # --- sizing ----------------------------------------------------------
      "Mod+R".action.switch-preset-column-width = [];
      "Mod+Shift+R".action.reset-window-height = [];
      "Mod+Minus".action.set-column-width = "-10%";
      "Mod+Equal".action.set-column-width = "+10%";
      "Mod+Shift+Minus".action.set-window-height = "-10%";
      "Mod+Shift+Equal".action.set-window-height = "+10%";

      # --- workspaces ------------------------------------------------------
      "Mod+1".action.focus-workspace = 1;
      "Mod+2".action.focus-workspace = 2;
      "Mod+3".action.focus-workspace = 3;
      "Mod+4".action.focus-workspace = 4;
      "Mod+5".action.focus-workspace = 5;
      "Mod+6".action.focus-workspace = 6;
      "Mod+7".action.focus-workspace = 7;
      "Mod+8".action.focus-workspace = 8;
      "Mod+9".action.focus-workspace = 9;

      "Mod+Shift+1".action.move-column-to-workspace = 1;
      "Mod+Shift+2".action.move-column-to-workspace = 2;
      "Mod+Shift+3".action.move-column-to-workspace = 3;
      "Mod+Shift+4".action.move-column-to-workspace = 4;
      "Mod+Shift+5".action.move-column-to-workspace = 5;
      "Mod+Shift+6".action.move-column-to-workspace = 6;
      "Mod+Shift+7".action.move-column-to-workspace = 7;
      "Mod+Shift+8".action.move-column-to-workspace = 8;
      "Mod+Shift+9".action.move-column-to-workspace = 9;

      "Mod+Page_Down".action.focus-workspace-down = [];
      "Mod+Page_Up".action.focus-workspace-up = [];
      "Mod+Tab".action.toggle-overview = [];

      # --- monitors --------------------------------------------------------
      "Mod+Ctrl+Left".action.focus-monitor-left = [];
      "Mod+Ctrl+Right".action.focus-monitor-right = [];
      "Mod+Shift+Ctrl+Left".action.move-column-to-monitor-left = [];
      "Mod+Shift+Ctrl+Right".action.move-column-to-monitor-right = [];

      # --- screenshots -----------------------------------------------------
      # `screenshot` opens niri's interactive UI; satty is wired in for
      # annotating the region afterwards via the screenshot directory.
      "Print".action.screenshot = [];
      "Ctrl+Print".action.screenshot-screen = [];
      "Alt+Print".action.screenshot-window = [];
      # niri's own screenshot actions save straight to disk. This one routes a
      # region through satty first for annotation.
      "Mod+Shift+S".action.spawn = "screenshot-annotate";

      # --- media / hardware keys ------------------------------------------
      "XF86AudioRaiseVolume" = {
        action.spawn = ["sh" "-c" "${wpctl} set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"];
        allow-when-locked = true;
      };
      "XF86AudioLowerVolume" = {
        action.spawn = ["sh" "-c" "${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%-"];
        allow-when-locked = true;
      };
      "XF86AudioMute" = {
        action.spawn = ["sh" "-c" "${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle"];
        allow-when-locked = true;
      };
      "XF86AudioMicMute" = {
        action.spawn = ["sh" "-c" "${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle"];
        allow-when-locked = true;
      };

      "XF86MonBrightnessUp" = {
        action.spawn = [brightness "set" "5%+"];
        allow-when-locked = true;
      };
      "XF86MonBrightnessDown" = {
        action.spawn = [brightness "set" "5%-"];
        allow-when-locked = true;
      };

      "XF86AudioPlay" = {
        action.spawn = [playerctl "play-pause"];
        allow-when-locked = true;
      };
      "XF86AudioNext" = {
        action.spawn = [playerctl "next"];
        allow-when-locked = true;
      };
      "XF86AudioPrev" = {
        action.spawn = [playerctl "previous"];
        allow-when-locked = true;
      };

      # --- session ---------------------------------------------------------
      "Mod+Shift+E".action.quit = [];
      "Mod+Shift+P".action.power-off-monitors = [];
      "Mod+Shift+Slash".action.show-hotkey-overlay = [];
    };

    window-rules = [
      # Rounded corners need clip-to-geometry, otherwise contents overflow the
      # rounded edge.
      {
        geometry-corner-radius = let
          r = 8.0;
        in {
          top-left = r;
          top-right = r;
          bottom-left = r;
          bottom-right = r;
        };
        clip-to-geometry = true;
      }

      # Password/secret surfaces must never land in a screen recording.
      {
        matches = [
          {app-id = "^org\\.keepassxc\\.KeePassXC$";}
          {app-id = "^Bitwarden$";}
        ];
        block-out-from = "screencast";
      }

      # Picture-in-picture, the Bluetooth GUI and the TUI control panels are
      # launched as one-off windows (see waybar.nix, which starts wiremix and
      # nmtui under these app-ids), so tiling them just displaces real work.
      #
      # `nmtui` rather than `impala`: impala is an iwd frontend and this host
      # runs NetworkManager with the wpa_supplicant backend (see
      # modules/nixos/core/networking.nix), so impala had no iwd D-Bus service to
      # talk to and crashed on launch. The app-id is the `foot -a` value in
      # waybar.nix, not the binary name, so these two must stay in sync.
      {
        matches = [
          {title = "^Picture-in-Picture$";}
          {app-id = "^overskride$";}
          {app-id = "^wiremix$";}
          {app-id = "^nmtui$";}
        ];
        open-floating = true;
      }
    ];

    layer-rules = [
      # Keep the launcher and notifications out of screencasts.
      {
        matches = [{namespace = "^launcher$";}];
        block-out-from = "screencast";
      }

      # No blur rule for waybar (namespace "waybar") on purpose. The niri binary
      # here is 26.04 and does support background-effect/blur, but niri-flake
      # generates this typed schema against niri 25.08, so `layer-rules` accepts
      # only baba-is-float, block-out-from, excludes, geometry-corner-radius,
      # matches, opacity, place-within-backdrop and shadow. Any blur spelling
      # fails at eval time and breaks the whole rebuild. The only escape hatch,
      # `programs.niri.config`, would replace this entire generated document.
      # The bar's translucency therefore comes from its own CSS rgba() alpha in
      # waybar.nix, which is what KDE did too ("blurBehind":false).
    ];

    # Laptop lid: lock before sleeping rather than after waking.
    switch-events.lid-close.action.spawn = ["sh" "-c" "${pkgs.systemd}/bin/loginctl lock-session"];

    animations = {
      slowdown = 0.8;
    };
  };
}
