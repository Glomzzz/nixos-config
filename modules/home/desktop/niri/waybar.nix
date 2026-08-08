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

      clock = {
        format = "{:%H:%M}";
        format-alt = "{:%Y-%m-%d %H:%M:%S}";
        tooltip-format = "<tt><small>{calendar}</small></tt>";
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

      network = {
        format-wifi = "󰖩 {essid}";
        format-ethernet = "󰈀";
        format-disconnected = "󰖪";
        tooltip-format = "{ifname}: {ipaddr}";
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
