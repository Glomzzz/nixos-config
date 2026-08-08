{
  config,
  lib,
  pkgs,
  ...
}: let
  clipboardHistory =
    lib.getExe'
    (lib.findSingle
      (p: (lib.getName p) == "clipboard-history")
      (throw "waybar: clipboard-history not found in home.packages (clipboard.nix)")
      (throw "waybar: more than one clipboard-history in home.packages")
      config.home.packages)
    "clipboard-history";
  # The battery popup. Waybar's menu support is a GtkBuilder file (see
  # waybar-menu(5)) whose ids are matched against the `menu-actions` keys, so
  # every id below MUST appear in that attrset or the item renders and silently
  # does nothing.
  #
  # Nesting uses `<child type="submenu">`, which is how GtkMenuItem's submenu
  # property is set from a builder file. It is real GTK3 and waybar reaches the
  # nested ids fine: ALabel walks the `menu-actions` keys and looks each one up
  # with gtk_builder_get_object, which resolves any id in the file regardless of
  # nesting depth, so the two submenus below are wired exactly like top-level
  # items. Verified by parsing this file with a real GtkBuilder: every id
  # resolves and profile/session each report an attached submenu.
  #
  # Every item here is a plain GtkMenuItem, and `prevent-lock` deliberately so
  # rather than the GtkCheckMenuItem it used to be. A check mark in this menu
  # cannot be kept truthful: ALabel builds the menu ONCE in its constructor and
  # drops the GtkBuilder, and the only later uses of the menu object are
  # show_all + popup_at_pointer, so there is no hook that could set an item's
  # active state from live system state afterwards.
  #
  # GTK also flips a GtkCheckMenuItem's mark by itself on every click,
  # independent of what the handler does, so the mark tracks CLICK PARITY, not
  # the inhibitor. Verified in real GTK: the mark starts unchecked on every
  # waybar start even while the inhibitor is held, and it stays checked after
  # the unit is stopped from outside the menu - i.e. it can show the exact
  # OPPOSITE of reality.
  #
  # The label therefore names the ACTION ("Toggle Prevent Lock") instead of
  # implying a state. The script behind it is the honest state: it reads
  # `systemctl --user is-active` and reports the resulting state through a
  # notification. Live togglers need a popup we own rather than waybar's
  # one-shot GtkBuilder menu.
  powerMenu = pkgs.writeText "waybar-power-menu.xml" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <interface>
      <object class="GtkMenu" id="menu">
        <child>
          <object class="GtkMenuItem" id="profile">
            <property name="label">Power Profile</property>
            <child type="submenu">
              <object class="GtkMenu" id="profile-menu">
                <child>
                  <object class="GtkMenuItem" id="profile-quiet">
                    <property name="label">Quiet</property>
                  </object>
                </child>
                <child>
                  <object class="GtkMenuItem" id="profile-balanced">
                    <property name="label">Balanced</property>
                  </object>
                </child>
                <child>
                  <object class="GtkMenuItem" id="profile-performance">
                    <property name="label">Performance</property>
                  </object>
                </child>
              </object>
            </child>
          </object>
        </child>
        <child>
          <object class="GtkMenuItem" id="prevent-lock">
            <property name="label">Toggle Prevent Lock</property>
          </object>
        </child>
        <child>
          <object class="GtkSeparatorMenuItem" id="separator1"/>
        </child>
        <child>
          <object class="GtkMenuItem" id="session">
            <property name="label">Session</property>
            <child type="submenu">
              <object class="GtkMenu" id="session-menu">
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
                  <object class="GtkSeparatorMenuItem" id="separator2"/>
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
                  <object class="GtkSeparatorMenuItem" id="separator3"/>
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
            </child>
          </object>
        </child>
      </object>
    </interface>
  '';

  swayncClient = lib.getExe' config.services.swaync.package "swaync-client";

  # asusd is the only power-management daemon enabled on this host
  # (hardware/zephyrus/asus.nix); there is no power-profiles-daemon and no tlp,
  # so `powerprofilesctl` does not exist here and asusctl is the correct client.
  # `asusctl profile set` takes the profile name as a positional argument and
  # the three names below are exactly what `asusctl profile list` reports.
  #
  # -e on notify-send is not used: asusctl already applies the change
  # synchronously, so the notification is purely confirmation, and reporting the
  # profile asusd actually ended up on (rather than the one requested) is what
  # makes a rejected change visible instead of silently claiming success.
  setProfile = pkgs.writeShellApplication {
    name = "waybar-set-profile";
    runtimeInputs = [pkgs.asusctl pkgs.libnotify];
    text = ''
      profile="$1"
      if ! asusctl profile set "$profile"; then
        notify-send -a Waybar -u critical "Power profile" "Failed to set $profile"
        exit 1
      fi
      notify-send -a Waybar -i battery "Power profile" "$(asusctl profile get | head -n1)"
    '';
  };

  # "Prevent lock" toggle. swayidle is what locks this session
  # (modules/home/desktop/niri/lock.nix), and swayidle 1.9 watches logind's
  # BlockInhibited property over PropertiesChanged and skips its timeouts while
  # an `idle` inhibitor is held - so taking a logind idle lock is what actually
  # suppresses the dim/lock/blank chain, rather than killing the service and
  # leaving the machine unlocked forever.
  #
  # `idle` only, deliberately: blocking `sleep` too would also override the lid
  # switch, and a laptop that no longer suspends when closed is a different
  # (and worse) behaviour than the one being asked for.
  #
  # The lock lives in a transient user unit rather than a background child of
  # waybar, because a child would die with the bar and leak on every waybar
  # restart. A named unit is also the state: `is-active` is the single source of
  # truth for whether the inhibitor is held, so the toggle cannot drift out of
  # sync with reality the way a stored flag file would.
  idleInhibit = pkgs.writeShellApplication {
    name = "waybar-idle-inhibit";
    runtimeInputs = [pkgs.systemd pkgs.libnotify];
    text = ''
      unit="waybar-prevent-lock"
      if systemctl --user --quiet is-active "$unit.service"; then
        systemctl --user stop "$unit.service"
        notify-send -a Waybar -i battery "Prevent lock" "Off - idle locking restored"
      else
        systemd-run --user --unit="$unit" --description="Waybar prevent lock" \
          systemd-inhibit --what=idle --who=Waybar --why="Prevent lock" \
          sleep infinity
        notify-send -a Waybar -i battery "Prevent lock" "On - screen will not lock"
      fi
    '';
  };

  weatherScript = pkgs.writeShellScript "waybar-weather" ''
    set -o pipefail

    fallback() {
      echo '{"text":"","tooltip":"weather unavailable","class":"unavailable"}'
      exit 0
    }

    # --fail turns HTTP >=400 into a non-zero exit (without it curl prints the
    # error body and exits 0, which would reach jq as garbage). --show-error
    # keeps the reason on stderr, where it lands in the waybar journal without
    # ever contaminating the JSON on stdout.
    raw=$(${pkgs.curl}/bin/curl \
      --max-time 10 \
      --retry 2 \
      --silent \
      --fail \
      --show-error \
      'https://api.open-meteo.com/v1/forecast?latitude=3.139&longitude=101.6869&current=temperature_2m,weather_code&timezone=Asia%2FSingapore') || fallback

    [ -n "$raw" ] || fallback

    # -e makes jq exit non-zero on a null/false result, and the explicit type
    # checks reject a well-formed response that is missing the fields (an API
    # shape change would otherwise render as the string "null").
    #
    # `time` is checked the same way and in the same guard as the two numeric
    # fields, not as a special case: it is interpolated into the tooltip's
    # "Updated ..." line, so a null or empty value would render literally as
    # "Updated null". Every field the output depends on shares one failure
    # path, so there is exactly one way for this module to degrade.
    fields=$(printf '%s' "$raw" | ${pkgs.jq}/bin/jq -er '
      .current as $c
      | if ($c.temperature_2m | type) != "number"
           or ($c.weather_code | type) != "number"
           or ($c.time | type) != "string"
           or ($c.time | length) == 0
        then error("open-meteo: current fields missing or of the wrong type")
        else "\($c.temperature_2m | round)\t\($c.weather_code)\t\($c.time)"
        end
    ') || fallback

    IFS="$(printf '\t')" read -r temp code obstime <<< "$fields" || fallback
    [ -n "$temp" ] && [ -n "$code" ] && [ -n "$obstime" ] || fallback

    # WMO 4677 present-weather codes, as documented by Open-Meteo. Glyphs are
    # material-design-icons from JetBrainsMono Nerd Font, each confirmed by
    # NAME in the font's cmap rather than by guessing a codepoint: 󰖙 F0599
    # md-weather_sunny, 󰖕 F0595 md-weather_partly_cloudy, 󰖐 F0590
    # md-weather_cloudy, 󰖑 F0591 md-weather_fog, 󰼳 F0F33
    # md-weather_partly_rainy, 󰙿 F067F md-weather_snowy_rainy, 󰖗 F0597
    # md-weather_rainy, 󰖖 F0596 md-weather_pouring, 󰖘 F0598 md-weather_snowy,
    # 󰖓 F0593 md-weather_lightning, 󰖒 F0592 md-weather_hail, 󰼯 F0F2F
    # md-weather_cloudy_alert for the default.
    #
    # The default arm matters: WMO has codes this case does not enumerate, and
    # an unmapped code must still render a glyph plus the number, so a gap is
    # visible and diagnosable instead of showing a blank module.
    case "$code" in
      0) icon="󰖙" desc="Clear sky" ;;
      1) icon="󰖕" desc="Mainly clear" ;;
      2) icon="󰖕" desc="Partly cloudy" ;;
      3) icon="󰖐" desc="Overcast" ;;
      45) icon="󰖑" desc="Fog" ;;
      48) icon="󰖑" desc="Depositing rime fog" ;;
      51) icon="󰼳" desc="Light drizzle" ;;
      53) icon="󰼳" desc="Moderate drizzle" ;;
      55) icon="󰼳" desc="Dense drizzle" ;;
      56) icon="󰙿" desc="Light freezing drizzle" ;;
      57) icon="󰙿" desc="Dense freezing drizzle" ;;
      61) icon="󰖗" desc="Slight rain" ;;
      63) icon="󰖗" desc="Moderate rain" ;;
      65) icon="󰖖" desc="Heavy rain" ;;
      66) icon="󰙿" desc="Light freezing rain" ;;
      67) icon="󰙿" desc="Heavy freezing rain" ;;
      71) icon="󰖘" desc="Slight snowfall" ;;
      73) icon="󰖘" desc="Moderate snowfall" ;;
      75) icon="󰖘" desc="Heavy snowfall" ;;
      77) icon="󰖘" desc="Snow grains" ;;
      80) icon="󰖗" desc="Slight rain showers" ;;
      81) icon="󰖗" desc="Moderate rain showers" ;;
      82) icon="󰖖" desc="Violent rain showers" ;;
      85) icon="󰖘" desc="Slight snow showers" ;;
      86) icon="󰖘" desc="Heavy snow showers" ;;
      95) icon="󰖓" desc="Thunderstorm" ;;
      96) icon="󰖒" desc="Thunderstorm with slight hail" ;;
      99) icon="󰖒" desc="Thunderstorm with heavy hail" ;;
      *) icon="󰼯" desc="Unmapped WMO code $code" ;;
    esac

    # Compact glyph + integer Celsius in `text`, mirroring KDE's
    # showTemperatureInCompactMode; the fuller line goes in the tooltip.
    #
    # The tooltip's line breaks are joined BY jq rather than written as
    # literal newlines in this string. A multi-line shell argument here
    # would carry this Nix indented string's leading whitespace into the
    # tooltip, and alejandra re-indents the whole block on every format
    # run, so the rendered tooltip would silently shift with the formatter.
    # jq -n with --arg also does all the JSON escaping, so the degree sign
    # and any punctuation in $desc cannot break the contract.
    ${pkgs.jq}/bin/jq -cn \
      --arg icon "$icon" \
      --arg desc "$desc" \
      --arg temp "$temp" \
      --arg code "$code" \
      --arg obstime "$obstime" \
      '{
         text: "\($icon) \($temp)°C",
         tooltip: ([
           "Kuala Lumpur: \($desc)",
           "\($temp)°C  (WMO \($code))",
           "Updated \($obstime)"
         ] | join("\n")),
         class: "weather"
       }' || fallback
  '';
  # nmtui in the bar's Catppuccin Mocha palette.
  #
  # nmtui is a newt (libnewt) application, and newt has exactly one theming
  # mechanism: the NEWT_COLORS/NEWT_COLORS_FILE environment variables, parsed by
  # parseColors() into `key=fg,bg` pairs. There is no config file and no runtime
  # option, so an env var is not a workaround here - it IS the API.
  #
  # NEWT_COLORS_FILE rather than NEWT_COLORS because initColors() reads the
  # inline variable with strncpy into a fixed 16KB buffer and checks the file
  # only when NEWT_COLORS is unset; a file keeps the 23 pairs off the process
  # environment and out of every `ps e` listing.
  #
  # The `#rrggbb` values are passed through newt untouched to SLtt_set_color,
  # and S-Lang emits them as 24-bit SGR (ESC[38;2;r;g;bm). Verified in a real
  # terminal: nmtui rendered with truecolor sequences carrying these exact
  # Catppuccin channels, so the hex is honoured rather than being silently
  # rounded to one of newt's eight legacy colour names.
  #
  # Every key parseColors() understands is set. A partial palette is what makes
  # a "themed" newt app look broken: any key left out keeps its default from
  # newtDefaultColorPalette, which is a light-on-blue scheme, so one unset key
  # shows up as a bright panel in the middle of a dark dialog.
  nmtuiColors = pkgs.writeText "nmtui-newt-colors" ''
    root=#cdd6f4,#11111b
    roottext=#a6adc8,#11111b
    border=#cdd6f4,#1e1e2e
    window=#cdd6f4,#1e1e2e
    shadow=#11111b,#11111b
    title=#89b4fa,#1e1e2e
    button=#11111b,#89b4fa
    actbutton=#11111b,#b4befe
    compactbutton=#cdd6f4,#1e1e2e
    checkbox=#cdd6f4,#313244
    actcheckbox=#11111b,#89b4fa
    entry=#cdd6f4,#313244
    disentry=#6c7086,#313244
    label=#bac2de,#1e1e2e
    listbox=#cdd6f4,#1e1e2e
    actlistbox=#11111b,#89b4fa
    sellistbox=#cdd6f4,#45475a
    actsellistbox=#11111b,#89b4fa
    textbox=#cdd6f4,#1e1e2e
    acttextbox=#11111b,#89b4fa
    helpline=#a6adc8,#181825
    emptyscale=white,#313244
    fullscale=white,#89b4fa
  '';

  # A wrapper rather than a session variable, because the palette has to reach
  # nmtui through waybar, and the bar runs as a systemd user service whose unit
  # carries an empty Environment= - home.sessionVariables never lands in the
  # process that spawns this command, so setting the variable session-wide would
  # theme nmtui in a shell and leave the bar's copy at newt's light default.
  #
  # This wrapper therefore governs the bar's launch path only. `nmtui` typed in a
  # shell resolves to the NetworkManager binary in the system profile and is
  # deliberately left alone: theming every newt application on the machine is a
  # system-wide decision that does not belong to the waybar module.
  nmtui = pkgs.writeShellApplication {
    name = "nmtui-themed";
    runtimeInputs = [pkgs.networkmanager];
    text = ''
      export NEWT_COLORS_FILE="${nmtuiColors}"
      exec nmtui "$@"
    '';
  };

  netspeed = pkgs.writeShellApplication {
    name = "waybar-netspeed";
    runtimeInputs = [pkgs.coreutils pkgs.gawk pkgs.jq pkgs.networkmanager];
    text = ''
      INTERVAL="''${INTERVAL:-1}"
      # Virtual interfaces are excluded from BOTH the byte counters and the
      # link lookup below, using the same list, so the rate and the tooltip
      # always describe the same set of interfaces. tailscale0 is in the list
      # because its counters double-count traffic that already passed through
      # the physical link.
      EXCLUDE='^(lo|docker|veth|br-|virbr|vnet|tun|tap|wg|zt|tailscale)'

      sample() {
        awk -F'[: ]+' -v ex="$EXCLUDE" '
          NR > 2 { if ($2 ~ ex) next; rx += $3; tx += $11 }
          END    { printf "%d %d\n", rx, tx }
        ' /proc/net/dev
      }

      # The rate is scaled once and returned as two fields - magnitude and unit
      # - so the caller can render it twice with different padding. The label
      # needs a constant width; the tooltip reads like prose. One pre-padded
      # string cannot satisfy both.
      #
      # The magnitude is held to the 0.0 shape (at most two integer digits),
      # which is what fixes the label width: 99.9 is the largest value shown in
      # any unit, and anything above it escalates to the next unit instead of
      # growing a third digit, so 123.1 B renders as 0.1 KB.
      #
      # The guard is 99.95 rather than 100 because the comparison has to be made
      # against the value that will be PRINTED, not the value held. %.1f rounds
      # 99.96 up to "100.0" - three integer digits, one column too wide - so the
      # escalation has to happen just below the rounding boundary.
      #
      # Units run to EB so the loop's counter, not the end of the list, is what
      # stops the scaling: a 64-bit counter cannot exceed 16 EB, so no rate can
      # run off the end and print a bare magnitude with no unit.
      #
      # The trailing newline is load-bearing: writeShellApplication sets
      # `errexit`, and `read` reports failure at EOF without a line delimiter,
      # so omitting it kills the module before it prints its first line.
      scale() {
        awk -v b="$1" 'BEGIN {
          split("B KB MB GB TB PB EB", u)
          i = 1
          while (b >= 99.95 && i < 7) { b /= 1024; i++ }
          printf "%.1f\t%s\n", b, u[i]
        }'
      }

      # Always exactly 7 columns: 4 for the magnitude, one real space, 2 for the
      # unit. BOTH fields are right-aligned, so the label grows leftward from a
      # fixed right edge and the decimal point, the digits and the unit each
      # hold their own column:
      #
      # - %4s right-aligns the magnitude, so "9.0" pads to " 9.0" and lines its
      #   decimal point up under the one in "99.9". Padding on the left is what
      #   the arrow needs: the digits stay flush against the gap after it
      #   instead of drifting away from it when the value is short.
      # - %2s right-aligns the unit so it ENDS at the same column every time:
      #   "B" becomes " B" and lines up under the "B" of "KB".
      #
      # The gap between the two is a literal space rather than padding, so it
      # survives however wide either field renders.
      #
      # Verified across 0 B .. 16 EB: every label is 7 characters.
      pad() { printf '%4s %2s' "$1" "$2"; }

      # nmcli -t does NOT escape colons inside values, so it is only safe on
      # fields that cannot contain one. DEVICE, TYPE and STATE cannot; a
      # connection name or an SSID can, which is why those are fetched with -g
      # (which escapes them as "\:") and unescaped explicitly below.
      unescape() { printf '%s' "''${1//\\:/:}"; }

      # First connected physical device wins. `device status` lists devices in
      # NetworkManager's own priority order, so the first match is the link
      # actually carrying traffic rather than whichever interface sorts first.
      primary() {
        nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | awk -F: -v ex="$EXCLUDE" '
          $1 ~ ex           { next }
          $2 == "wifi-p2p"  { next }
          $3 != "connected" { next }
          { printf "%s\t%s\n", $1, $2; exit }
        '
      }

      devfield() {
        unescape "$(nmcli -g "$1" device show "$2" 2>/dev/null | head -n1)"
      }

      # SSID is requested LAST so the fields before it - none of which can
      # contain a colon - can be split off positionally and everything
      # remaining rejoined as the SSID, whatever it contains.
      wifi_ap() {
        nmcli -g ACTIVE,SIGNAL,RATE,SSID device wifi list ifname "$1" --rescan no 2>/dev/null |
          awk -F: '
            $1 == "yes" {
              ssid = $4
              for (i = 5; i <= NF; i++) ssid = ssid ":" $i
              printf "%s\t%s\t%s\n", $2, $3, ssid
              exit
            }
          '
      }

      # Labels are padded to one width so every value starts in the same column.
      row() { printf '%-10s %s\n' "$1:" "$2"; }

      # The tooltip answers "what am I connected through" - the question the
      # label cannot answer, since the label is already showing the rate. It
      # deliberately does NOT repeat the two numbers.
      conninfo() {
        local dev type name addr gw signal rate ssid out
        IFS=$'\t' read -r dev type < <(primary) || true

        if [ -z "''${dev:-}" ]; then
          printf 'Disconnected'
          return
        fi

        name=$(devfield GENERAL.CONNECTION "$dev")
        addr=$(devfield IP4.ADDRESS "$dev")
        gw=$(devfield IP4.GATEWAY "$dev")

        out=""
        case "$type" in
          ethernet)
            out+="$(row Link 'Ethernet')"$'\n'
            [ -n "$name" ] && out+="$(row Profile "$name")"$'\n'
            ;;
          wifi)
            IFS=$'\t' read -r signal rate ssid < <(wifi_ap "$dev") || true
            # The SSID arrives colon-escaped, because it is the one field here
            # that can legitimately contain a colon and so had to be fetched
            # with -g. Unescaping is what turns "Cafe\:Free" back into
            # "Cafe:Free"; without it the backslash reaches the tooltip.
            ssid=$(unescape "''${ssid:-}")
            out+="$(row Link 'Wi-Fi')"$'\n'
            out+="$(row Network "''${ssid:-''${name:-unknown}}")"$'\n'
            [ -n "''${signal:-}" ] && out+="$(row Signal "$signal%")"$'\n'
            [ -n "''${rate:-}" ] && out+="$(row Rate "$rate")"$'\n'
            ;;
          *)
            out+="$(row Link "$type")"$'\n'
            [ -n "$name" ] && out+="$(row Profile "$name")"$'\n'
            ;;
        esac

        out+="$(row Interface "$dev")"$'\n'
        [ -n "$addr" ] && out+="$(row IPv4 "$addr")"$'\n'
        [ -n "$gw" ] && out+="$(row Gateway "$gw")"

        printf '%s' "''${out%$'\n'}"
      }

      # The link does not change every second, and each refresh costs four
      # nmcli round trips, so it is re-read on a slower cadence than the rate
      # and reused in between. Primed before the loop so the very first line
      # already carries a populated tooltip.
      TOOLTIP_EVERY=5
      tip=$(conninfo)
      ticks=0

      read -r prx ptx < <(sample)
      while true; do
        sleep "$INTERVAL"
        read -r crx ctx < <(sample)
        down=$(( (crx - prx) / INTERVAL ))
        up=$((   (ctx - ptx) / INTERVAL ))
        prx=$crx; ptx=$ctx

        ticks=$(( ticks + 1 ))
        if [ "$ticks" -ge "$TOOLTIP_EVERY" ]; then
          tip=$(conninfo)
          ticks=0
        fi

        IFS=$'\t' read -r dnum dunit < <(scale "$down")
        IFS=$'\t' read -r unum uunit < <(scale "$up")

        # jq builds the JSON so an SSID containing a quote, a backslash or a
        # newline cannot break the contract with waybar. It also encodes the
        # real newlines below, so the label and the tooltip are written here as
        # ordinary multi-line text rather than as hand-escaped "\n".
        jq -cn \
          --arg down "$(pad "$dnum" "$dunit")" \
          --arg up "$(pad "$unum" "$uunit")" \
          --arg tip "$tip" \
          '{
             text: "↓ \($down)\n↑ \($up)",
             tooltip: $tip,
             class: "netspeed"
           }'
      done
    '';
  };
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
      modules-center = ["clock" "custom/weather"];
      # it in both places instantiates the module TWICE - two icons, two D-Bus
      # watchers, and the shared #bluetooth CSS applying to both - so the drawer
      # membership is the single home for it.
      modules-right = [
        "group/tray-drawer"
        "group/sensors"
        "pulseaudio"
        "bluetooth"
        "custom/notification"
        "battery"
      ];

      "custom/launcher" = {
        format = "󱄅";
        tooltip = false;
        on-click = "${pkgs.fuzzel}/bin/fuzzel";
      };

      "niri/workspaces" = {
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
        interval = 1;
        timezone = "Asia/Singapore";
        locale = "en_US.UTF-8";
        format = "{:%Y-%m-%d %H:%M:%S}";
        format-alt = "{:%a %d %b %Y  %H:%M:%S}";
        tooltip-format = "<tt><small>{calendar}</small></tt>";
        calendar = {
          mode = "month";
          mode-mon-col = 3;
          weeks-pos = "left";
          on-scroll = 1;
          format = {
            months = "<span color='#89b4fa'><b>{}</b></span>";
            days = "<span color='#cdd6f4'>{}</span>";
            weeks = "<span color='#6c7086'><b>W{}</b></span>";
            weekdays = "<span color='#a6adc8'><b>{}</b></span>";
            today = "<span color='#f38ba8'><b><u>{}</u></b></span>";
          };
        };
        actions = {
          on-click-right = "mode";
          on-scroll-up = "shift_up";
          on-scroll-down = "shift_down";
        };
      };

      "custom/weather" = {
        return-type = "json";
        interval = 900;
        exec = "${weatherScript}";
        escape = true;
      };

      "custom/notification" = {
        return-type = "json";
        exec = "${swayncClient} -swb";
        on-click = "${swayncClient} -t -sw";
        on-click-right = "${swayncClient} -d -sw";
        format = "{icon}";
        format-icons = {
          notification = "󰂚";
          none = "󰂜";
          dnd-notification = "󰂛";
          dnd-none = "󰂛";
          inhibited-notification = "󰂠";
          inhibited-none = "󰂠";
          dnd-inhibited-notification = "󰂛";
          dnd-inhibited-none = "󰂛";
        };
        escape = true;
        tooltip = false;
      };

      pulseaudio = {
        format = "{icon} {volume}%";
        format-muted = "󰝟";
        format-icons.default = ["󰕿" "󰖀" "󰕾"];
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

        menu = "on-click";
        menu-file = "${powerMenu}";
        # One entry per id in powerMenu above. The two submenu PARENTS
        # (`profile`, `session`) are deliberately absent: GTK opens a submenu on
        # hover by itself, and giving a parent an action would run it when the
        # user is only reaching for a child.
        menu-actions = {
          profile-quiet = "${setProfile}/bin/waybar-set-profile Quiet";
          profile-balanced = "${setProfile}/bin/waybar-set-profile Balanced";
          profile-performance = "${setProfile}/bin/waybar-set-profile Performance";
          prevent-lock = "${idleInhibit}/bin/waybar-idle-inhibit";
          lock = "${pkgs.swaylock-effects}/bin/swaylock -f";
          logout = "${pkgs.niri}/bin/niri msg action quit";
          suspend = "${pkgs.systemd}/bin/systemctl suspend";
          hibernate = "${pkgs.systemd}/bin/systemctl hibernate";
          reboot = "${pkgs.systemd}/bin/systemctl reboot";
          shutdown = "${pkgs.systemd}/bin/systemctl poweroff";
        };
      };

      # Network speed, CPU load and temperature are one reading of "what is this
      # machine doing right now", so they live in a group and share a single
      # separator instead of each carrying its own.
      #
      # `orientation = "inherit"` is required, not cosmetic: a group's default
      # orientation is "orthogonal", which in this horizontal bar would stack the
      # three modules vertically. Group boxes are also constructed with GTK
      # spacing hardcoded to 0 (unlike the bar's own `spacing = 6`), so the
      # members sit flush and their CSS padding is the only gap - which is what
      # makes cpu and temperature read as one pair.
      "group/sensors" = {
        orientation = "inherit";
        modules = [
          "custom/network"
          "cpu"
          "temperature"
        ];
      };

      cpu = {
        interval = 2;
        format = "󰻠 {usage}%";
        tooltip = true;
      };

      temperature = {
        interval = 2;
        hwmon-path-abs = "/sys/devices/platform/coretemp.0/hwmon";
        input-filename = "temp1_input";
        warning-threshold = 95;
        critical-threshold = 105;
        format = "󰔏 {temperatureC}°C";
        format-critical = "󰸁 {temperatureC}°C";
        tooltip-format = "CPU package: {temperatureC}°C ({temperatureF}°F)";
      };

      # nmtui, not impala: impala is an iwd frontend, and this host runs
      # NetworkManager over wpa_supplicant (modules/nixos/core/networking.nix)
      # with no iwd service and no net.connman.iwd on the bus at all, so impala
      # panicked on startup ("reader source not set" / "No such device or
      # address") every time it was clicked. nmtui talks to the daemon this
      # machine actually runs.
      "custom/network" = {
        exec = "${netspeed}/bin/waybar-netspeed";
        return-type = "json";
        format = "{}";
        restart-interval = 5;
        tooltip = true;
        # Waybar hands the tooltip to GTK as Pango MARKUP, not as plain text, so
        # an SSID containing "&" or "<" would either vanish or blank the whole
        # tooltip. The script builds its JSON with jq, which protects the JSON
        # contract but says nothing about markup; `escape` is the layer that
        # makes the value safe once it is inside that JSON. Same reason
        # custom/weather sets it.
        escape = true;
        on-click = "${pkgs.foot}/bin/foot -a nmtui ${nmtui}/bin/nmtui-themed";
      };

      "group/tray-drawer" = {
        orientation = "inherit";
        drawer = {
          transition-duration = 500;
          children-class = "tray-drawer-child";
          click-to-reveal = true;
        };
        modules = [
          "tray"
          "mpris"
          "backlight"
          "niri/language"
          "custom/clipboard"
          "privacy"
        ];
      };

      tray = {
        spacing = 8;
        icon-size = 20;
        show-passive-items = true;
      };

      bluetooth = {
        format = "󰂯 {status}";
        format-disabled = "󰂲";
        format-off = "󰂲";
        format-on = "󰂯";
        format-connected = "󰂱 {num_connections}";
        format-no-controller = "󰂲";
        tooltip-format = "{controller_alias}\n{controller_address}";
        tooltip-format-off = "Bluetooth off\n{controller_alias}";
        tooltip-format-disabled = "Bluetooth disabled";
        tooltip-format-on = "Bluetooth on, nothing connected\n{controller_alias}";

        # Every connected device is listed, one per line. waybar builds
        # {device_enumerate} by running the two `-enumerate-` formats below once
        # per entry in its connected-device list, so the list is complete by
        # construction - there is no cap and no "focussed device" filtering.
        #
        # The device block is wrapped in <tt> because the columns are aligned
        # with SPACES, and space is only a fixed advance in a monospaced font.
        # In the tooltip's default proportional font the padding computed below
        # renders as ragged gaps. Verified against Pango: the same padded string
        # measures one width under a monospace family and drifts under the UI
        # font. The header stays outside the <tt> so it keeps the tooltip's
        # normal face.
        #
        # NOTE: waybar hands this to set_tooltip_markup WITHOUT escaping it, and
        # the device alias comes from BlueZ. An alias containing & or < is
        # therefore invalid markup and GTK drops the whole tooltip. That is an
        # upstream limitation with no config-side fix - the alias never reaches
        # anything here that could escape it - and it is pre-existing rather
        # than introduced by this block. Renaming such a device in BlueZ is the
        # only workaround.
        tooltip-format-connected = "{controller_alias}\n{num_connections} connected\n\n<tt>{device_enumerate}</tt>";

        # Both row formats put the address at the SAME column so the two kinds
        # interleave as one table:
        #
        # - {:<16.16} pins the alias to 16 columns. The precision is what makes
        #   it a hard field rather than a minimum: without `.16` a long alias
        #   pushes everything after it rightward and only THAT row misaligns.
        # - {:>3}% right-aligns the battery so 7%, 90% and 100% share a column.
        # - The plain row pays for the whole missing battery field with eight
        #   spaces: 2 separator + 3 digits + 1 "%" + 2 separator. Getting this
        #   count wrong by one is exactly the bug this comment exists to
        #   prevent, and it is invisible until a device without a battery sits
        #   next to one that has it.
        #
        # Verified with real fmt against this host's aliases plus adversarial
        # ones (overlong alias, 0%, 100%): the address starts at column 24 on
        # every row, battery or not.
        tooltip-format-enumerate-connected = "{device_alias:<16.16}        {device_address}";
        tooltip-format-enumerate-connected-battery = "{device_alias:<16.16}  {device_battery_percentage:>3}%  {device_address}";
        on-click = "${pkgs.overskride}/bin/overskride";
      };

      mpris = {
        player = "playerctld";
        format = "{status_icon} {dynamic}";
        format-stopped = "󰝚";
        status-icons = {
          playing = "󰐊";
          paused = "󰏤";
          stopped = "󰓛";
        };
        dynamic-order = ["title" "artist"];
        title-len = 32;
        artist-len = 20;
        max-length = 48;
        tooltip-format = "{status_icon} {title}\n{artist}\n{album}\n{player}";
      };

      # KDE's clipboard applet. Reuses the exact cliphist+fuzzel picker that
      # Mod+Shift+C is bound to (see the clipboardHistory binding at the top of
      # this file) rather than re-declaring the pipeline, so the button and the
      # keybind cannot drift apart. 󰅍 U+F014D md-clipboard_text.
      #
      # A plain `custom` with no `exec` is a static button: waybar renders
      # `format` verbatim and only runs the click handler. No return-type, no
      # interval, no polling.
      "custom/clipboard" = {
        format = "󰅍";
        tooltip = false;
        on-click = "${clipboardHistory}";
      };

      privacy = {
        icon-size = 18;
        icon-spacing = 4;
        transition-duration = 250;
        modules = [
          {
            type = "screenshare";
            tooltip = true;
            tooltip-icon-size = 24;
          }
        ];
      };
    };

    style = ''
      /* ===================================================================
         Panel geometry and shared resets.

         height = 32 in the config above matches KDE's `thickness=32`, so the
         only job here is to stop GTK from adding its own chrome on top of it:
         `min-height: 0` lets a widget shrink to the bar's height instead of
         GTK's default minimum, and the border/radius resets clear the theme's
         button decoration so every module starts from the same flat surface.

         The transition is declared once, globally, so that every colour and
         fill change in the bar animates at the same speed - the workspace
         pills, the hover tints and the battery/temperature state colours all
         inherit it rather than each cluster picking its own timing. GTK3
         supports `transition` and `@keyframes`; it has no CSS backdrop
         filtering at all, so no such property appears anywhere in this sheet -
         translucency comes from the rgba() base below and nothing else.
         =================================================================== */
      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 13px;
        border: none;
        border-radius: 0;
        min-height: 0;
        transition:
          background-color 150ms ease-in-out,
          color 150ms ease-in-out;
      }

      /* KDE ran this panel at `panelOpacity=0` with the colorizer applet
         painting a translucent Catppuccin surface over it, so an rgba() base is
         the faithful equivalent rather than a stopgap. The alpha IS the final
         appearance: niri-flake's typed layer-rules schema has no blur or
         background-effect attribute, so nothing will ever be composited behind
         this surface. Keep the alpha below 1.0.

         The hairline bottom border is what KDE's panel shadow did - it stops
         the bar dissolving into a light wallpaper - and it is deliberately a
         translucent surface1 rather than a solid line so it reads as an edge,
         not as a frame. */
      window#waybar {
        background: rgba(30, 30, 46, 0.92);
        color: #cdd6f4;
        border-bottom: 1px solid rgba(69, 71, 90, 0.6);
      }

      /* ===================================================================
         Left cluster: launcher, workspace pills, window title.
         =================================================================== */

      /* The pill row is its own visual group, so the container carries no
         decoration of its own - the buttons' margins do the spacing and the
         group reads as a run of pills rather than a boxed widget. */
      #workspaces {
        padding: 0 4px;
      }

      /* niri sets several of these classes on the SAME button - the focused
         workspace is also its output's .active one, and an on-demand workspace
         can be .empty while focused - so the four rules below genuinely
         compete and the way each conflict is resolved differs. Two mechanisms
         are at work, and neither is "later always wins":

         - .empty vs .focused is a real source-order tie. Both are one id, one
           type and one class, so specificity cannot separate them and GTK3
           falls back to document order. .focused is written last for exactly
           that reason; moving it above .empty would leave a focused-but-empty
           pill drawn dim.
         - .active:not(.focused) vs .focused is NOT decided by order. :not()
           contributes its argument's specificity, so that selector counts two
           classes and outranks .focused outright. It is also disjoint from it
           by construction - a focused button cannot match :not(.focused) - so
           the pair never actually collides. The guard, not the position, is
           what stops the secondary blue text landing on the filled pill.

         Net effect: keep .focused after .empty (order is load-bearing there),
         and keep the :not(.focused) guard on .active (specificity and mutual
         exclusion are load-bearing there). */
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
         Primary highlight, filled, and placed after .empty so it wins that
         equal-specificity tie when the focused workspace is also empty. */
      #workspaces button.focused {
        color: #1e1e2e;
        background: #89b4fa;
      }

      #workspaces button.urgent {
        color: #f38ba8;
      }

      /* The window title is the quietest thing in the bar - it changes on every
         focus change, so it reads as secondary text (#a6adc8) rather than
         competing with the pills next to it. */
      #window {
        color: #a6adc8;
        padding: 0 10px;
      }

      /* ===================================================================
         Shared module geometry.

         One padding value for every text module in the centre and right
         clusters, so the bar has a single horizontal rhythm instead of each
         module carrying its own. The bar's `spacing = 6` sits on top of this,
         which is what keeps neighbours inside a cluster distinguishable
         without a separator between every one of them.
         =================================================================== */
      #clock,
      #pulseaudio,
      #backlight,
      #battery,
      #language,
      #tray {
        padding: 0 10px;
        color: #cdd6f4;
      }

      /* The centre cluster is the bar's headline, so the clock and the weather
         reading are the one place the 13px body size is overridden upward: 17px
         is the largest size that still fits the 32px panel with room for the
         font's descenders (~1.2x line height puts 17px at ~21px of ink), and it
         leaves the right cluster's readouts as clearly secondary text.

         Both selectors carry the SAME size on purpose - they sit next to each
         other in modules-center and read as one unit, so a mismatch here would
         look like a bug rather than a hierarchy. The clock also gets a mild
         letter-spacing because it is monospaced digits that change every
         second; the extra tracking stops the seconds column from looking
         cramped at this size. */
      #clock {
        font-size: 17px;
        font-weight: 600;
        letter-spacing: 0.3px;
      }

      #custom-weather {
        font-size: 17px;
      }

      /* The sensors group is one cluster, so its members get a tighter 4px
         inner padding than the 10px above - the group box has GTK spacing 0, so
         this padding is the ONLY gap between them and 4px is what pulls cpu and
         temperature together into a readable pair. #custom-network keeps a
         little more room on its left so the trio does not touch the separator.

         `#network` is deliberately NOT in this list: that id belongs to waybar's
         built-in network module, which this bar does not use. The netspeed
         readout is `custom/network`, so it is `#custom-network`. */
      #cpu,
      #temperature {
        padding: 0 4px;
        color: #cdd6f4;
      }

      /* ===================================================================
         Cluster separators - CSS, not modules.

         KDE broke this panel up with three third-party
         `zayron.simple.separator` plasmoids (applets 58-61). Reproducing that
         with waybar modules would mean adding fake custom modules that poll
         nothing and exist only to draw a line, so the separator is a border on
         the FIRST module of each cluster instead: indicators | volume+battery |
         sensors | session.

         The line is a 1px-wide background gradient rather than a border plus
         `margin: 6px 0`, and that is a layout fix, not a style preference. A
         vertical margin is added to the widget's height request, and waybar
         grows the bar to whatever its tallest module asks for (it logs
         "Requested height: 32 is less than the minimum height: N"). With the
         two-line netspeed label inside #sensors, a 6px margin pushed the bar
         from 32px to 44px - measured, one variant per margin value. Painting
         the line into the background instead requests no extra space at all, so
         the shortened line survives and `height = 32` is actually honoured.

         The stops reproduce exactly what the margin did visually: transparent
         for the first 6px, surface1 from 6px to 26px, transparent again to the
         bottom - a 20px line centred in a 32px bar, the same proportion as
         KDE's `lengthSeparator=80`. `background-size: 1px 100%` keeps it
         hairline-thin and full-height, and no-repeat stops GTK tiling it across
         the whole module.
         =================================================================== */
      /* #sensors, not #cpu: the sensors trio is a group now, so the line goes on
         the group box and the three members inside it are separator-free. A
         border on #cpu would draw a line BETWEEN the netspeed readout and the cpu
         readout, splitting the very cluster this groups them into. */
      #pulseaudio,
      #sensors,
      #custom-notification {
        background-image: linear-gradient(
          to bottom,
          transparent 0,
          transparent 6px,
          rgba(69, 71, 90, 0.6) 6px,
          rgba(69, 71, 90, 0.6) 26px,
          transparent 26px,
          transparent 100%
        );
        background-size: 1px 100%;
        background-position: left center;
        background-repeat: no-repeat;
      }

      /* ===================================================================
         Right cluster: volume, battery, sensors.
         =================================================================== */

      /* Muted is a state the user chose, so it recedes to the same overlay0
         grey #bluetooth.off and the DND states use rather than warning. */
      #pulseaudio.muted {
        color: #6c7086;
      }

      #battery.warning {
        color: #f9e2af;
      }

      #battery.critical {
        color: #f38ba8;
      }

      /* On mains, so the percentage stops being a warning at all - green wins
         over the two rules above on source order, which is deliberate: a
         charging battery at 12% should not read as an emergency. */
      #battery.charging,
      #battery.plugged {
        color: #a6e3a1;
      }

      /* The one animation in the bar, and only for the state that genuinely
         needs to interrupt: critical AND still discharging. GTK3 implements
         @keyframes, so this is a real blink rather than a silent no-op. The
         :not(.charging) guard stops it the moment the cable goes in. */
      @keyframes battery-blink {
        to {
          color: #1e1e2e;
          background: #f38ba8;
        }
      }

      #battery.critical:not(.charging) {
        animation-name: battery-blink;
        animation-duration: 1.2s;
        animation-timing-function: ease-in-out;
        animation-iteration-count: infinite;
        animation-direction: alternate;
        border-radius: 6px;
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

      /* The netspeed readout, and the one module in the bar whose width must not
         move: it re-renders every second, so a single character of drift would
         shove the whole right cluster sideways once a second.

         Two mechanisms hold it still, and BOTH are needed:
         - The script pads every value to exactly 6 characters, unit included, so
           "   0 B", " 1.0KB" and " 1.4MB" occupy the same number of glyphs. That
           is what leaves room for B/KB/MB/GB without a reflow.
         - `monospace` is what makes 6 equal characters mean 6 equal pixels. The
           nerd font is monospaced, but the fallback must be too, or a glyph
           served from a proportional fallback would undo the padding.

         min-width is the floor for the two-line label; the padding above it is
         symmetric so the text stays centred inside that floor. font-size is
         11px rather than the bar's 13px because this is the only module drawing
         TWO stacked lines inside the 32px bar. */
      #custom-network {
        font-family: "JetBrainsMono Nerd Font", monospace;
        font-size: 11px;
        min-width: 54px;
        padding: 0 6px;
        color: #cdd6f4;
      }

      /* ===================================================================
         Clickable affordance.

         KDE's applets all highlighted under the pointer, and that is the only
         cue a module does something when pointed at - waybar draws no button
         chrome of its own. Every module listed here really is interactive:
         #clock through its `actions` block,
         #pulseaudio/#custom-network/#bluetooth through `on-click`, and
         #pulseaudio/#backlight additionally through the scroll handling those two
         modules implement natively. #battery is here too now: its `menu` opens
         the power popup, so it IS clickable.

         `#custom-network`, not `#network`: the old selector named waybar's
         built-in network module, which this bar does not use, so the netspeed
         readout never actually highlighted despite having an on-click.

         #window, #cpu, #temperature and #custom-weather are deliberately absent -
         none of them has an action, so highlighting them would advertise a click
         that does nothing. The fill animates via the global transition.

         `background-color`, NOT the `background` shorthand: #pulseaudio carries
         its cluster separator as a background-image (see the separator block
         above), and the shorthand resets every background property it does not
         mention - so `background: #45475a` here would silently delete that
         separator line for as long as the pointer rests on the module. Naming
         the colour channel alone leaves the image untouched. */
      #clock:hover,
      #pulseaudio:hover,
      #custom-network:hover,
      #battery:hover,
      #bluetooth:hover,
      #backlight:hover {
        background-color: #45475a;
        border-radius: 6px;
      }

      /* The four selectors waybar-tray(5) documents. `#tray > .x` reaches the
         individual SNI item widgets inside the tray box, so the three status
         classes are per-icon, not per-module. Passive items are dimmed rather
         than hidden, which is the point of show-passive-items = true: an idle
         item is still there, just visually demoted. needs-attention is the
         SNI equivalent of KDE's blinking/highlighted tray member. */
      #tray > .passive {
        -gtk-icon-effect: dim;
      }

      #tray > .active {
        -gtk-icon-effect: none;
      }

      #tray > .needs-attention {
        -gtk-icon-effect: highlight;
        background: #f38ba8;
        border-radius: 6px;
      }

      /* The drawer group. #tray-drawer is the group's own box (bar.cpp strips
         the "group/" prefix to build the widget name), and .tray-drawer-child
         is the children-class set explicitly in the drawer config above - it
         lands on every module in the group EXCEPT the leader. Left padding
         separates a revealed child from the always-visible tray, and the hover
         tint on the group is the only affordance that it is clickable, since
         click-to-reveal means nothing happens on mouse-over. */
      #tray-drawer {
        padding: 0 2px;
        border-radius: 8px;
      }

      #tray-drawer:hover {
        background: #45475a;
      }

      .tray-drawer-child {
        padding: 0 6px;
        color: #a6adc8;
      }

      /* The secondary indicator cluster - bluetooth, media, clipboard and the
         privacy dot. These all live inside the drawer, so .tray-drawer-child
         already gives them padding and the dimmed #a6adc8; the rules below
         only add what is specific to each one. Every selector
         here is one waybar-<module>(5) documents - #bluetooth with its state
         classes, #mpris with its per-status class, #custom-clipboard from the
         custom module's #custom-<name> contract, and #privacy/#privacy-item. */
      #bluetooth,
      #mpris,
      #custom-clipboard,
      #privacy {
        padding: 0 6px;
      }

      /* Off and disabled are the resting states, so they stay muted rather
         than shouting. Ordered off/disabled -> on -> connected so the brighter
         states win on source order, the same convention as the workspace
         pills above. */
      #bluetooth.off,
      #bluetooth.disabled {
        color: #6c7086;
      }

      #bluetooth.on {
        color: #a6adc8;
      }

      /* Connected is the state worth noticing, hence the accent blue - the
         same #89b4fa the focused workspace and the launcher use. */
      #bluetooth.connected {
        color: #89b4fa;
      }

      /* Pairing and discovery are transient and end up in a dialog anyway, so
         they get the yellow "in progress" colour shared with the warning
         states rather than a colour of their own. */
      #bluetooth.discoverable,
      #bluetooth.discovering,
      #bluetooth.pairable {
        color: #f9e2af;
      }

      /* mpris carries a variable-width track title, so it gets the only
         italic in the bar for paused and a green tint while playing: the
         module's width changes on its own and colour is what makes the state
         readable at a glance. */
      #mpris.playing {
        color: #a6e3a1;
      }

      #mpris.paused {
        color: #a6adc8;
        font-style: italic;
      }

      #mpris.stopped {
        color: #6c7086;
      }

      #custom-clipboard {
        color: #cdd6f4;
      }

      #custom-clipboard:hover {
        background: #45475a;
        border-radius: 6px;
      }

      /* #privacy is the container, #privacy-item each monitored type. Red,
         because the whole point is that it is alarming: something is capturing
         the screen. It renders nothing at all when idle, so this styling is
         only ever visible during an actual capture. */
      #privacy {
        color: #f38ba8;
      }

      #privacy-item {
        padding: 0 4px;
        color: #f38ba8;
      }

      #privacy-item.screenshare {
        color: #f38ba8;
      }

      /* Appended below the workspace rules on purpose - see the source-order
         note above. These selectors do not overlap them, so position is only a
         convention here, but keeping additions at the end keeps it that way. */
      /* The NixOS logo is the leftmost thing in the bar and it is a single
         glyph, so it is sized to fill the 32px panel rather than to match the
         13px body text next to it.

         23px, not larger, and the ceiling was measured rather than estimated:
         waybar asks the compositor for whichever height its widgets need, so an
         oversized glyph does not clip - it silently grows the whole bar past
         `height = 32`. Rendering this bar against a real compositor at 18..24px
         put every size up to 23px at exactly 32px and 24px at 33px, so 23px is
         the largest glyph that still fits the configured panel.

         `padding: 0` on the vertical axis matters for the same reason - any
         vertical padding is added to the glyph's ~28px ink box and would push
         the bar over 32px again, so the padding below is horizontal-only. */
      #custom-launcher {
        padding: 0 12px 0 14px;
        color: #89b4fa;
        font-size: 23px;
      }

      #custom-launcher:hover,
      #custom-power:hover {
        background: #45475a;
      }

      #custom-power {
        padding: 0 12px 0 10px;
        color: #f38ba8;
      }

      /* Weather sits beside the clock in modules-center, so it takes the same
         0 10px padding the shared #clock rule gives its neighbour and reads as
         one cluster with it. The two class values below are the ones the script
         actually emits - `weather` on success, `unavailable` on any failure
         path - and they exist so a dead API is visibly dimmed rather than
         indistinguishable from a real reading. */
      #custom-weather {
        padding: 0 10px;
        color: #cdd6f4;
      }

      /* Yellow, the same "something is off" colour #battery.warning and
         #temperature.warning use, so an unavailable reading is noticeable
         without shouting like the red critical states. `text` is empty in that
         branch, so this only ever colours the tooltip-bearing gap. */
      #custom-weather.unavailable {
        color: #f9e2af;
      }

      /* The notification indicator. It sits in modules-right between the
         battery and the power button, so it takes the same 0 10px padding the
         shared #clock/#battery rule gives its neighbours and reads as part of
         that cluster.

         The eight class values below are exactly the eight format-icons keys -
         swaync-client emits one of them per line and waybar sets it as a class
         on this widget. They are mutually exclusive, so unlike the workspace
         pills above no escalation is needed; the grouping is only for reading.
         Ordered resting -> suppressed -> pending anyway, to keep this file's
         one convention. */
      #custom-notification {
        padding: 0 10px;
        color: #cdd6f4;
      }

      /* Nothing waiting: the resting state, so it recedes to the same dimmed
         #a6adc8 the drawer children use rather than sitting at full text
         brightness beside modules that actually have something to say. */
      #custom-notification.none {
        color: #a6adc8;
      }

      /* Do-not-disturb, with or without an inhibitor. Overlay0 - the same
         "switched off" grey #bluetooth.off and the low-urgency swaync border
         use - because DND is a state the user chose and should read as muted,
         not as a fault. The two dnd-*-notification classes are deliberately
         grouped here rather than with the red pending rules below: under DND a
         waiting notification is being suppressed on purpose, and colouring it
         red would defeat the whole point of the toggle. The glyph already
         differs (md-bell_off), so the state is still distinguishable. */
      #custom-notification.dnd-none,
      #custom-notification.dnd-notification,
      #custom-notification.dnd-inhibited-none,
      #custom-notification.dnd-inhibited-notification {
        color: #6c7086;
      }

      /* An inhibitor without DND: popups are held back by an application
         (screen share, fullscreen) rather than by the user, and it lifts on its
         own. Yellow, the transient "in progress" colour shared with
         #battery.warning and #bluetooth.discovering. */
      #custom-notification.inhibited-none,
      #custom-notification.inhibited-notification {
        color: #f9e2af;
      }

      /* Unread and nothing suppressing it - the one state that should pull the
         eye. Red #f38ba8, the same accent as #privacy and the critical states,
         which is also the colour upstream's snippet hard-coded into a Pango
         <span>; keeping it here instead means the palette lives in one place
         and the module can keep escape = true. Last, so it wins on source
         order over the base rule. */
      #custom-notification.notification {
        color: #f38ba8;
      }

      /* `background-color` for the same reason as the hover block above: this
         module carries a separator background-image, and the shorthand would
         drop it while hovered. */
      #custom-notification:hover {
        background-color: #45475a;
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
