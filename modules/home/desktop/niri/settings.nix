{
  config,
  pkgs,
  xwayland-satellite,
  ...
}: let
  # PR #452's satellite, pinned in flake.nix. Release 0.8.2 in nixpkgs cannot
  # scale X11 clients per monitor at all; see the input's comment there and the
  # base scale in hardware/zephyrus/gpu.
  #
  # The patch fixes the input-method candidate window appearing offset from the
  # caret in X11 apps: satellite repositioned popups relative to the whole X
  # screen instead of relative to the parent window, because it re-derived the
  # parent from WM_TRANSIENT_FOR, which fcitx5's override-redirect popup does
  # not set. The patch file's header explains it in full.
  xwaylandSatellite =
    xwayland-satellite.packages.${pkgs.stdenv.hostPlatform.system}.xwayland-satellite.overrideAttrs
    (old: {
      patches =
        (old.patches or [])
        ++ [../../../../patches/xwayland-satellite-popup-parent-offset.patch];
    });
  terminal = "${pkgs.foot}/bin/foot";
  launcher = "${pkgs.fuzzel}/bin/fuzzel";
  emacs = config.programs.emacs.finalPackage;
  # No emacs daemon runs in this session (see programs/dev/editor/emacs.nix),
  # so this launches a standalone frame rather than emacsclient.
  editor = "${emacs}/bin/emacs";
  filemanager = [editor "--dirvish"];
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
      # Scales are pinned rather than left to niri's DPI heuristic so the
      # positions below stay valid. 2560x1600 at scale 1.5 is 1706.67 logical
      # pixels wide, so the external monitor starts at x=1707 to sit flush to
      # its right. x=1706 would overlap the panel by a fraction of a pixel, and
      # niri responds to any overlap by discarding both explicit positions and
      # auto-placing instead. Keep this in step if the panel scale changes.
      "eDP-1" = {
        focus-at-startup = true;
        scale = 1.5;
        position = {
          x = 0;
          y = 0;
        };
      };
      "HDMI-A-1" = {
        scale = 1.0;
        position = {
          x = 1707;
          y = 0;
        };
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

      # Backs the Mod+Shift+R cycle. Without this list niri has no heights to
      # switch between and switch-preset-window-height does nothing, so the two
      # must be added together.
      preset-window-heights = [
        {proportion = 1.0 / 3.0;}
        {proportion = 1.0 / 2.0;}
        {proportion = 2.0 / 3.0;}
      ];

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

    # Read back from home.pointerCursor (desktop/cursor.nix) so the compositor
    # cursor and the XCURSOR_* variables every client sees stay in step.
    cursor = {
      theme = config.home.pointerCursor.name;
      size = config.home.pointerCursor.size;
      hide-when-typing = true;
    };

    # Only session-specific variables belong here. The Wayland toolkit hints
    # (NIXOS_OZONE_WL, QT_QPA_PLATFORM, MOZ_ENABLE_WAYLAND)
    # are set system-wide in hardware/zephyrus/gpu, and niri-session re-execs
    # as a login shell, so /etc/profile already exports them to everything niri
    # spawns. Repeating them here would just be two places to keep in sync.
    environment = {
      # Xwayland apps launched by niri find the satellite display here.
      DISPLAY = ":0";
    };

    # niri 26.04 starts the satellite itself, on demand, the first time a client
    # connects to the X11 socket it owns. Naming the binary here rather than
    # adding it to spawn-at-startup is what makes that integration use this
    # build; a spawn-at-startup entry would start a *second*, unmanaged
    # satellite alongside niri's own (both were running before this change,
    # each with its own Xwayland).
    #
    # The base scale that goes with this build is XWAYLAND_SATELLITE_BASE_SCALE
    # in hardware/zephyrus/gpu. It cannot be set in the environment block below:
    # niri builds the satellite's command itself and never applies that block to
    # it, so the variable has to be in niri's own environment.
    xwayland-satellite = {
      enable = true;
      path = "${xwaylandSatellite}/bin/xwayland-satellite";
    };

    # niri has no XDG-autostart handling of its own, so anything that must be
    # running for the session to feel complete is spawned explicitly.
    # Wallpaper, clipboard, notifications and idle locking are systemd user
    # services instead (see the sibling modules).
    spawn-at-startup = [
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
      "Mod+E".action.spawn = filemanager;
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
      # Modifier scheme, applied consistently below:
      #   Mod              - move focus inside the current workspace
      #   Mod+Shift        - move the window/column inside the current workspace
      #   Mod+Ctrl         - cross workspaces (up/down) and monitors (left/right)
      #   Mod+Shift+Ctrl   - carry the column across workspaces/monitors
      # Every directional bind exists in both an arrow and an hjkl spelling.
      "Mod+Left".action.focus-column-left = [];
      "Mod+Right".action.focus-column-right = [];
      "Mod+Up".action.focus-window-up = [];
      "Mod+Down".action.focus-window-down = [];
      "Mod+H".action.focus-column-left = [];
      "Mod+L".action.focus-column-right = [];
      "Mod+K".action.focus-window-up = [];
      "Mod+J".action.focus-window-down = [];

      # Jump to the ends of the scrolling row.
      "Mod+Home".action.focus-column-first = [];
      "Mod+End".action.focus-column-last = [];

      # Alt-tab equivalents: last window, last workspace.
      "Mod+Grave".action.focus-window-previous = [];
      "Mod+Shift+Grave".action.focus-workspace-previous = [];

      # Floating and tiling are separate focus planes in niri; without this
      # bind a floating window can only be reached with the pointer.
      "Mod+Shift+V".action.switch-focus-between-floating-and-tiling = [];

      # --- moving ----------------------------------------------------------
      "Mod+Shift+Left".action.move-column-left = [];
      "Mod+Shift+Right".action.move-column-right = [];
      "Mod+Shift+Up".action.move-window-up = [];
      "Mod+Shift+Down".action.move-window-down = [];
      "Mod+Shift+H".action.move-column-left = [];
      "Mod+Shift+L".action.move-column-right = [];
      "Mod+Shift+K".action.move-window-up = [];
      "Mod+Shift+J".action.move-window-down = [];

      "Mod+Shift+Home".action.move-column-to-first = [];
      "Mod+Shift+End".action.move-column-to-last = [];

      # Swap with the neighbouring window rather than reordering columns.
      # Mod+Alt+* is the workspace/monitor-level modifier below, so swap uses
      # Mod+Shift+Alt to stay out of its way.
      "Mod+Shift+Alt+H".action.swap-window-left = [];
      "Mod+Shift+Alt+L".action.swap-window-right = [];

      # Column composition: pull the neighbour into this column, or push the
      # bottom window back out into its own column.
      "Mod+Comma".action.consume-window-into-column = [];
      "Mod+Period".action.expel-window-from-column = [];
      "Mod+BracketLeft".action.consume-or-expel-window-left = [];
      "Mod+BracketRight".action.consume-or-expel-window-right = [];

      # --- sizing ----------------------------------------------------------
      "Mod+R".action.switch-preset-column-width = [];
      # Cycles layout.preset-window-heights, the vertical counterpart of Mod+R.
      # Resetting to automatic height moved to Mod+Ctrl+R.
      "Mod+Shift+R".action.switch-preset-window-height = [];
      "Mod+Ctrl+R".action.reset-window-height = [];
      "Mod+Minus".action.set-column-width = "-10%";
      "Mod+Equal".action.set-column-width = "+10%";
      "Mod+Shift+Minus".action.set-window-height = "-10%";
      "Mod+Shift+Equal".action.set-window-height = "+10%";
      # Grow the column into whatever space the other visible columns leave.
      "Mod+Ctrl+F".action.expand-column-to-available-width = [];

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

      # Move the view up/down the workspace stack. Mod+Ctrl+J/K mirrors the
      # arrow spellings so the vertical axis is reachable without leaving the
      # home row; Page_Up/Down stay for muscle memory.
      "Mod+Page_Down".action.focus-workspace-down = [];
      "Mod+Page_Up".action.focus-workspace-up = [];
      "Mod+Ctrl+J".action.focus-workspace-down = [];
      "Mod+Ctrl+K".action.focus-workspace-up = [];
      "Mod+Ctrl+Down".action.focus-workspace-down = [];
      "Mod+Ctrl+Up".action.focus-workspace-up = [];

      # Carry the focused column with you across workspaces. This is the
      # vertical counterpart of Mod+Shift+Ctrl+Left/Right for monitors.
      "Mod+Shift+Page_Down".action.move-column-to-workspace-down = [];
      "Mod+Shift+Page_Up".action.move-column-to-workspace-up = [];
      "Mod+Shift+Ctrl+J".action.move-column-to-workspace-down = [];
      "Mod+Shift+Ctrl+K".action.move-column-to-workspace-up = [];
      "Mod+Shift+Ctrl+Down".action.move-column-to-workspace-down = [];
      "Mod+Shift+Ctrl+Up".action.move-column-to-workspace-up = [];

      # Reorder the workspaces themselves rather than moving windows between
      # them. Alt is the "operate on the workspace" modifier.
      "Mod+Alt+Page_Down".action.move-workspace-down = [];
      "Mod+Alt+Page_Up".action.move-workspace-up = [];
      "Mod+Alt+J".action.move-workspace-down = [];
      "Mod+Alt+K".action.move-workspace-up = [];

      "Mod+Tab".action.toggle-overview = [];

      # Mouse wheel over the workspace stack. cooldown-ms rate-limits the
      # continuous scroll stream so one flick does not fly through ten
      # workspaces; the niri wiki recommends this for scroll binds.
      "Mod+WheelScrollDown" = {
        action.focus-workspace-down = [];
        cooldown-ms = 150;
      };
      "Mod+WheelScrollUp" = {
        action.focus-workspace-up = [];
        cooldown-ms = 150;
      };
      "Mod+WheelScrollRight".action.focus-column-right = [];
      "Mod+WheelScrollLeft".action.focus-column-left = [];

      # --- monitors --------------------------------------------------------
      # Left/right only covers this desk's layout (eDP-1 at x=0, HDMI-A-1 to
      # its right), but up/down and previous/next are bound too so a rearranged
      # or stacked output setup does not need a config change to be reachable.
      "Mod+Ctrl+Left".action.focus-monitor-left = [];
      "Mod+Ctrl+Right".action.focus-monitor-right = [];
      "Mod+Ctrl+H".action.focus-monitor-left = [];
      "Mod+Ctrl+L".action.focus-monitor-right = [];
      "Mod+Ctrl+Tab".action.focus-monitor-next = [];
      "Mod+Ctrl+Shift+Tab".action.focus-monitor-previous = [];

      "Mod+Shift+Ctrl+Left".action.move-column-to-monitor-left = [];
      "Mod+Shift+Ctrl+Right".action.move-column-to-monitor-right = [];
      "Mod+Shift+Ctrl+H".action.move-column-to-monitor-left = [];
      "Mod+Shift+Ctrl+L".action.move-column-to-monitor-right = [];

      # Send the whole workspace to the other screen, which is what you
      # actually want when docking or undocking mid-task.
      "Mod+Alt+Left".action.move-workspace-to-monitor-left = [];
      "Mod+Alt+Right".action.move-workspace-to-monitor-right = [];
      "Mod+Alt+H".action.move-workspace-to-monitor-left = [];
      "Mod+Alt+L".action.move-workspace-to-monitor-right = [];

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

      # Steam draws its own toasts ("friend is now playing X", chat pings) as
      # separate X11 windows instead of going through the notification daemon,
      # so swaync never sees them and cannot place them. They arrive through
      # xwayland-satellite as ordinary xdg-toplevels whose app-id is the
      # WM_CLASS class ("steam") and whose title is notificationtoasts_N_desktop.
      #
      # niri centres them because it has no idea where Steam wanted them: the
      # xdg-toplevel protocol has no position request, so the X11 coordinates
      # Steam picked never reach the compositor, and niri's default position for
      # a new floating window is the centre of the screen. The toast lands in
      # the floating layout in the first place because niri auto-floats
      # fixed-height windows. Naming a position is therefore the only fix; there
      # is no "leave it where the client asked" mode.
      #
      # open-focused = false additionally stops a toast from stealing focus
      # mid-keystroke, which centring made especially disruptive.
      {
        matches = [
          {
            app-id = "^steam$";
            title = "^notificationtoasts_[0-9]+_desktop$";
          }
        ];
        open-floating = true;
        open-focused = false;
        default-floating-position = {
          x = 16;
          y = 16;
          relative-to = "bottom-right";
        };
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
