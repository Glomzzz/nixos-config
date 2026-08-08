{pkgs, ...}: let
  # Ported from KDE's kickoff applet, which carried
  # systemFavorites=suspend,hibernate,reboot,shutdown, plus lock and logout to
  # match the Mod+Escape and Mod+Shift+E binds in settings.nix.
  #
  # waybar's `menu` mechanism wants a GtkBuilder document with a GtkMenu whose
  # id is exactly `menu`; every other id here is the key that `menu-actions`
  # binds a command to. Generated into the store so the path in `menu-file`
  # cannot drift from the ids below, and so nothing depends on $HOME.
  powerMenu = pkgs.writeText "waybar-power-menu.xml" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <interface>
      <object class="GtkMenu" id="menu">
        <child>
          <object class="GtkMenuItem" id="lock">
            <property name="label">Lock</property>
          </object>
        </child>
        <child>
          <object class="GtkMenuItem" id="logout">
            <property name="label">Log Out</property>
          </object>
        </child>
        <child>
          <object class="GtkSeparatorMenuItem" id="separator1"/>
        </child>
        <child>
          <object class="GtkMenuItem" id="suspend">
            <property name="label">Suspend</property>
          </object>
        </child>
        <child>
          <object class="GtkMenuItem" id="hibernate">
            <property name="label">Hibernate</property>
          </object>
        </child>
        <child>
          <object class="GtkSeparatorMenuItem" id="separator2"/>
        </child>
        <child>
          <object class="GtkMenuItem" id="reboot">
            <property name="label">Restart</property>
          </object>
        </child>
        <child>
          <object class="GtkMenuItem" id="shutdown">
            <property name="label">Shut Down</property>
          </object>
        </child>
      </object>
    </interface>
  '';
in {
  # Waybar has had native niri modules since 0.11.0 (nixpkgs ships 0.15.0), so
  # workspace state comes from niri's own IPC rather than a helper script.
  programs.waybar = {
    enable = true;

    systemd = {
      enable = true;
      # niri.service binds to graphical-session.target, so the default target
      # is correct here and the bar comes up with the session.
      enableInspect = false;
    };

    settings.main = {
      layer = "top";
      position = "top";
      height = 32;
      spacing = 6;

      modules-left = ["custom/launcher" "niri/workspaces" "niri/window"];
      modules-center = ["clock"];
      modules-right = [
        "tray"
        "niri/language"
        "pulseaudio"
        "backlight"
        "battery"
        "cpu"
        "temperature"
        "network"
        "custom/power"
      ];

      # KDE's kickoff sat at the far left with icon=nix-snowflake; U+F1105 is
      # Nerd Fonts' nf-linux-nixos, the same mark. Static text, so no `exec`.
      "custom/launcher" = {
        format = "󱄅";
        tooltip = false;
        on-click = "${pkgs.fuzzel}/bin/fuzzel";
      };

      # U+F0425 nf-md-power. `menu` names the event that opens the popup; the
      # keys of `menu-actions` are the GtkMenuItem ids in powerMenu above.
      "custom/power" = {
        format = "󰐥";
        tooltip = false;
        menu = "on-click";
        menu-file = "${powerMenu}";
        menu-actions = {
          lock = "${pkgs.swaylock-effects}/bin/swaylock -f";
          # No --skip-confirmation: this matches the Mod+Shift+E bind
          # (`quit = []` in settings.nix), and a stray menu click should not
          # tear the session down without niri's own confirm prompt.
          logout = "${pkgs.niri}/bin/niri msg action quit";
          suspend = "${pkgs.systemd}/bin/systemctl suspend";
          hibernate = "${pkgs.systemd}/bin/systemctl hibernate";
          reboot = "${pkgs.systemd}/bin/systemctl reboot";
          shutdown = "${pkgs.systemd}/bin/systemctl poweroff";
        };
      };

      "niri/workspaces" = {
        # {value} renders the workspace name, falling back to its index, so the
        # number is visible. KDE's pager was per-screen, hence all-outputs off.
        format = "{value}";
        all-outputs = false;
      };

      "niri/window" = {
        format = "{title}";
        max-length = 60;
        separate-outputs = true;
      };

      "niri/language" = {
        format = "{short}";
        tooltip = false;
      };

      # KDE's digital clock ran use24hFormat=2, showSeconds=Always,
      # dateFormat=isoDate and dateDisplayFormat=BesideTime, so the default
      # format is the ISO date sitting beside a 24-hour clock with seconds.
      # interval must be 1: at the default 60 the seconds field would sit
      # frozen for a whole minute.
      #
      # showWeekNumbers=true maps to calendar.weeks-pos. `locale` is set
      # because waybar-clock(5) states {calendar} takes its start-of-week from
      # this option rather than the system locale; en_US.UTF-8 matches LC_TIME
      # in modules/nixos/core/locale.nix, giving Sunday-start weeks and the
      # default %U week numbering.
      #
      # Two honest gaps versus KDE. waybar renders the calendar INSIDE the
      # tooltip, not as a separate popup window, so it is hover-only and
      # cannot be pinned open. And KDE's three calendar plugins
      # (alternatecalendar, astronomicalevents, holidaysevents) have no waybar
      # equivalent at all - they are dropped, recorded in the parity ledger.
      clock = {
        interval = 1;
        timezone = "Asia/Singapore";
        locale = "en_US.UTF-8";
        format = "{:%Y-%m-%d %H:%M:%S}";
        format-alt = "{:%a %d %b %Y  %H:%M:%S}";
        tooltip-format = "<tt><small>{calendar}</small></tt>";
        calendar = {
          mode = "month";
          mode-mon-col = 3;
          # The direct equivalent of KDE's showWeekNumbers=true.
          weeks-pos = "left";
          on-scroll = 1;
          # Catppuccin Mocha, same palette as the style block below. Pango
          # markup, not CSS - the calendar is tooltip text, so #clock rules
          # cannot reach it.
          format = {
            months = "<span color='#89b4fa'><b>{}</b></span>";
            days = "<span color='#cdd6f4'>{}</span>";
            weeks = "<span color='#6c7086'><b>W{}</b></span>";
            weekdays = "<span color='#a6adc8'><b>{}</b></span>";
            today = "<span color='#f38ba8'><b><u>{}</u></b></span>";
          };
        };
        # Scroll shifts months and right-click cycles year/month, covering the
        # navigation KDE's calendar popup had. Plain on-click is left alone so
        # it keeps toggling format-alt. No tz_up/tz_down: those need
        # `timezones`, which conflicts with the single `timezone` above.
        actions = {
          on-click-right = "mode";
          on-scroll-up = "shift_up";
          on-scroll-down = "shift_down";
        };
      };

      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = "󰝟";
        format-icons.default = ["󰕿" "󰖀" "󰕾"];
        # wiremix replaces pavucontrol as the mixer.
        on-click = "${pkgs.foot}/bin/foot -a wiremix ${pkgs.wiremix}/bin/wiremix";
      };

      backlight = {
        format = "󰃟 {percent}%";
        tooltip = false;
      };

      battery = {
        states = {
          warning = 30;
          critical = 15;
        };
        format = "{icon} {capacity}%";
        format-charging = "󰂄 {capacity}%";
        format-icons = ["󰁺" "󰁼" "󰁾" "󰂀" "󰂂"];
      };

      # KDE's applet 53 was a piechart whose total sensor was
      # cpu/all/averageTemperature, with averageFrequency/system/usage/user/wait
      # demoted to low-priority (tooltip-only) sensors. Split across waybar's
      # two native modules: `cpu` carries the usage figure and the frequency
      # detail, `temperature` carries the package reading the chart was keyed
      # on. U+F0EE0 nf-md-cpu_64_bit.
      #
      # Deliberately no GPU counterpart. KDE's applet 52 charted
      # gpu/gpu0/temperature; it is dropped on purpose, because every polling
      # route to the NVIDIA card (nvidia-smi included) wakes the dGPU, and
      # todo 2 confirmed no GPU hwmon node exists to read passively either.
      cpu = {
        interval = 2;
        format = "󰻠 {usage}%";
        tooltip = true;
      };

      # thermal-zone is NOT used: thermal_zone0 here is acpitz, the real
      # package sensor is thermal_zone7 (x86_pkg_temp), and that index is not
      # stable across linuxPackages_latest bumps. The platform-device hwmon
      # path is stable. The hwmon# leaf is intentionally absent from
      # hwmon-path-abs - waybar-temperature(5) says the module appends
      # hwmon*/<input-filename> itself. temp1_label reads "Package id 0", the
      # die aggregate, which is the closest analogue to KDE's averageTemperature.
      #
      # Thresholds are tuned to THIS machine, not copied from dotfiles. Package
      # readings observed 87-96C (91 idle, 96 under an 8-way busy loop), and
      # temp1_crit/temp1_max both read 110000. A conventional 80C warning would
      # therefore be lit permanently and mean nothing, so warning sits at 95
      # (just above the idle band, so it fires on real sustained load) and
      # critical at 105 (5C of headroom below the 110C hardware limit).
      temperature = {
        interval = 2;
        hwmon-path-abs = "/sys/devices/platform/coretemp.0/hwmon";
        input-filename = "temp1_input";
        warning-threshold = 95;
        critical-threshold = 105;
        format = "󰔏 {temperatureC}°C";
        # U+F0E01 nf-md-thermometer_alert, so the critical state reads
        # differently even before the CSS colour lands.
        format-critical = "󰸁 {temperatureC}°C";
        tooltip-format = "CPU package: {temperatureC}°C ({temperatureF}°F)";
      };

      # KDE's applet 27 was org.kde.netspeedWidget with speedLayout=rows and
      # swapDownUp=true, i.e. two stacked rows with download on top. Waybar has
      # no netspeed module and a single module renders ONE row, so the two rows
      # collapse to one line with download first, separated by arrows:
      # "↓ 1.2MB/s ↑ 34kB/s". That row/inline difference is the one honest gap
      # versus KDE here and is recorded in the parity ledger (todo 18).
      #
      # interval = 2 because the documented default is 60 - at 60 the rate would
      # be a stale minute-old average, where KDE polled continuously. 2 matches
      # the cpu/temperature cadence above.
      #
      # Every token below is verbatim from the installed waybar-network(5):
      # the Bytes pair reads as human units (kB/s, MB/s) rather than the Bits
      # pair's raw bit counts, which is what KDE's widget displayed.
      network = {
        interval = 2;
        format-wifi = "󰖩 {essid}  ↓ {bandwidthDownBytes} ↑ {bandwidthUpBytes}";
        format-ethernet = "󰈀  ↓ {bandwidthDownBytes} ↑ {bandwidthUpBytes}";
        format-disconnected = "󰖪";
        # {signalStrength} is wifi-only, so the wired tooltip uses gateway and
        # netmask instead of carrying a permanently empty percentage.
        tooltip-format = "{ifname}: {ipaddr}\nGateway: {gwaddr}\n↓ {bandwidthDownBytes}  ↑ {bandwidthUpBytes}";
        tooltip-format-wifi = "{essid} ({signalStrength}%, {signaldBm} dBm)\n{ifname}: {ipaddr}\nGateway: {gwaddr}\n↓ {bandwidthDownBytes}  ↑ {bandwidthUpBytes}";
        tooltip-format-ethernet = "{ifname}: {ipaddr}/{cidr}\nGateway: {gwaddr}\n↓ {bandwidthDownBytes}  ↑ {bandwidthUpBytes}";
        tooltip-format-disconnected = "Disconnected";
        # impala is the wifi TUI replacing the plasma applet.
        on-click = "${pkgs.foot}/bin/foot -a impala ${pkgs.impala}/bin/impala";
      };

      tray.spacing = 8;
    };

    # Catppuccin Mocha, matching foot and fuzzel.
    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
        border: none;
        border-radius: 0;
        min-height: 0;
      }

      window#waybar {
        background: rgba(30, 30, 46, 0.92);
        color: #cdd6f4;
      }

      /* Rule order below is load-bearing. GTK3 resolves equal-specificity
         selectors by source order, and niri sets several of these classes on
         the SAME button (the focused workspace is also .active, and may also
         be .empty). So they escalate: base -> empty -> active -> focused. */
      #workspaces button {
        padding: 0 8px;
        margin: 4px 2px;
        border-radius: 8px;
        color: #cdd6f4;
        background: #45475a;
      }

      /* Occupied pills read brighter than niri's on-demand empty ones. */
      #workspaces button.empty {
        color: #6c7086;
        background: transparent;
      }

      /* .active is per-output: the workspace each monitor is displaying. The
         weaker secondary highlight (no fill) so the bar on the monitor WITHOUT
         keyboard focus still marks its visible workspace. :not(.focused) keeps
         this text colour off the filled pill, which would be blue-on-blue. */
      #workspaces button.active:not(.focused) {
        color: #89b4fa;
        background: transparent;
        border-bottom: 2px solid #89b4fa;
      }

      /* .focused is globally unique: the one workspace holding keyboard focus.
         Primary highlight, filled, and last so it wins over the rules above. */
      #workspaces button.focused {
        color: #1e1e2e;
        background: #89b4fa;
      }

      #workspaces button.urgent {
        color: #f38ba8;
      }

      #window {
        color: #a6adc8;
        padding: 0 10px;
      }

      #clock,
      #pulseaudio,
      #backlight,
      #battery,
      #cpu,
      #temperature,
      #network,
      #language,
      #tray {
        padding: 0 10px;
        color: #cdd6f4;
      }

      #battery.warning {
        color: #f9e2af;
      }

      #battery.critical {
        color: #f38ba8;
      }

      /* Same two-step escalation as #battery, and the same palette, so the
         temperature readout turns yellow then red the way KDE's piechart
         recoloured its wedge. Placed after the shared padding rule above for
         the same reason #battery's states are - id+class outranks a bare id,
         but keeping the order consistent avoids relying on that. */
      #temperature.warning {
        color: #f9e2af;
      }

      #temperature.critical {
        color: #f38ba8;
      }

      /* Appended below the workspace rules on purpose - see the source-order
         note above. These selectors do not overlap them, so position is only a
         convention here, but keeping additions at the end keeps it that way. */
      #custom-launcher {
        padding: 0 10px 0 12px;
        color: #89b4fa;
        font-size: 16px;
      }

      #custom-launcher:hover,
      #custom-power:hover {
        background: #45475a;
      }

      #custom-power {
        padding: 0 12px 0 10px;
        color: #f38ba8;
      }

      /* The session popup is a real GtkMenu, not a waybar widget, so it is
         styled by element name rather than by id. */
      menu {
        background: #1e1e2e;
        color: #cdd6f4;
        border: 1px solid #45475a;
        border-radius: 8px;
        padding: 4px;
      }

      menu menuitem {
        padding: 4px 12px;
        border-radius: 6px;
      }

      menu menuitem:hover {
        background: #89b4fa;
        color: #1e1e2e;
      }
    '';
  };
}
