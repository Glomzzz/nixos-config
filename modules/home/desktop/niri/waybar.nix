# waybar replaces the KDE Plasma top panel this machine used to run. The panel's
# full applet inventory lived in ~/.config/plasma-org.kde.plasma.desktop-appletsrc
# (containment 26, AppletOrder at :421 = 33;58;55;60;69;57;59;31;34;61;54;32;53;
# 52;27;36;63;35;66;56), and the ledger below records what happened to every one
# of them, plus the system tray's own members. It is kept here rather than in a
# separate document because the outcome of an applet is only meaningful next to
# the module that replaced it. "DROPPED" means the function is genuinely gone,
# not relocated - each such line says why, so nothing looks like an oversight.
#
# Panel applets, in KDE's own AppletOrder sequence:
#
#   33 kickoff          -> custom/launcher, a static nf-linux-nixos glyph opening
#                          fuzzel; the power entries kickoff carried in
#                          systemFavorites moved to custom/power's GtkMenu.
#   58 separator        -> CSS. The four zayron.simple.separator plasmoids became
#                          border-left + margin on the first module of each
#                          cluster, so there is no separator module at all.
#   55 userswitcher     -> DROPPED - single-user machine, and its config set
#                          showFace=true/showName=false, so it only ever drew an
#                          avatar; waybar's `user` module would add a face and no
#                          switching, which is decoration rather than parity.
#   60 separator        -> CSS, as 58.
#   69 notes            -> DROPPED - a sticky-note editor with persisted body
#                          text has no bar analogue in waybar, and reimplementing
#                          one as a custom module is a new app, not a port.
#   57 windowtitle      -> niri/window, which reads the focused window straight
#                          from the compositor instead of the Fork applet's
#                          KWin-specific scripting bridge.
#   59 separator        -> CSS, as 58.
#   31 panelspacer      -> layout, not a module: the modules-left/modules-center/
#                          modules-right split reproduces the gap KDE opened with
#                          an expanding spacer.
#   34 digitalclock     -> clock, with the calendar in the tooltip. KDE's
#                          alternatecalendar, astronomicalevents and
#                          holidaysevents plugins are DROPPED - waybar's calendar
#                          has no plugin surface to hang them on.
#   61 separator        -> CSS, as 58.
#   54 weather          -> custom/weather (keyless Open-Meteo, Kuala Lumpur),
#                          de-duplicated: KDE ran the weather applet twice, once
#                          on the panel and once inside the tray, and this ports
#                          it once next to the clock where AppletOrder had it.
#   32 panelspacer      -> layout, as 31.
#   53 systemmonitor    -> cpu + temperature. KDE's CPU instance graphed
#      (CPU)               cpu/all/averageTemperature; the pair here shows load
#                          and that same temperature as text.
#   52 systemmonitor    -> DROPPED by explicit decision - the GPU instance polled
#      (GPU)               gpu/gpu0/temperature, and on this Optimus laptop any
#                          periodic NVIDIA query wakes the discrete GPU, so the
#                          reading would cost battery for its own sake.
#   27 netspeedWidget   -> folded into network. KDE used speedLayout=rows with
#                          swapDownUp=true, i.e. two stacked rows; one waybar
#                          module renders one row, so throughput is inline,
#                          download first, arrows as separators. Degraded, not
#                          dropped: both figures are still on the bar.
#   36 systemtray       -> tray plus a click-to-reveal group. Degraded: waybar
#                          0.15.0 has no per-item show/hide and no memory of
#                          which item was hidden, and its drawer arrow toggles
#                          whole modules rather than individual SNI items, so
#                          KDE's remembered shownItems/hiddenItems split cannot
#                          be reproduced. Real tray icons stay visible; the
#                          indicator modules sit behind the click.
#   63 battery          -> battery, unchanged from its pre-existing form, which
#                          already showed the percentage KDE's applet did.
#   35 notifications    -> custom/notification driven by swaync-client -swb;
#                          swaync replaced mako precisely so the unread count,
#                          DND toggle and history panel KDE had could exist.
#   66 showdesktop      -> DROPPED - niri has no show-desktop or peek action to
#                          call, so the only route would be a new keybind, and
#                          keybind changes are outside this work's scope.
#   56 colorizer        -> CSS. The bar's translucent rgba background is the
#                          equivalent of the colorizer's panel tinting. Panel
#                          blur is DROPPED - it is not expressible in
#                          niri-flake's typed layer-rules schema (the flake
#                          generates types from niri 25.08 while the binary is
#                          26.04), so CSS alpha is the actual final appearance.
#                          No parity is lost: this panel had blurBehind=false.
#
# System tray members (containment 26, applet 36; extraItems at :211-216):
#
#   38 cameraindicator  -> privacy, scoped to screenshare only. The module's
#                          default also indicates audio-in; that is deliberately
#                          excluded because KDE never showed a microphone here.
#   39 clipboard        -> custom/clipboard, clicking through to the same
#                          cliphist+fuzzel picker Mod+Shift+C already opened.
#   44 kscreen          -> DROPPED - waybar has no display-configuration module,
#                          and output layout on niri is set declaratively in
#                          settings.nix rather than from a tray popup.
#   45 keyboardindicator-> niri/language, pre-existing and unchanged; it reports
#                          the fcitx5 input method KDE's indicator (hidden as
#                          "Fcitx" in hiddenItems) tracked.
#   46 weather          -> see panel applet 54; this was the duplicate instance.
#   47 volume           -> pulseaudio, pre-existing and unchanged.
#   49 mediacontroller  -> mpris following playerctld, title and artist only.
#   65 networkmanagement-> network, pre-existing, now also carrying the netspeed
#                          throughput folded in from applet 27.
#   66 printmanager     -> DROPPED - waybar has no print-queue module; CUPS keeps
#                          its own web interface at localhost:631 for the rare
#                          case a job needs attention.
#   68 brightness       -> backlight, pre-existing and unchanged (KDE kept this
#                          one in hiddenItems, so it was not visible there).
#      blueman          -> bluetooth, one of KDE's two shownItems, clicking
#                          through to overskride as the manager GUI.
#      kded6, Xwayland  -> N/A, Plasma internals with no standalone function;
#      Video Bridge        both were in hiddenItems and neither has a successor.
#      udiskie          -> N/A, its own tray icon appears in the tray module when
#                          the service runs; nothing waybar-side to port.
#
# Added, with no KDE counterpart: numbered workspace pills (niri/workspaces).
# KDE's top panel had no workspace switcher - the taskbar lived on a second,
# bottom panel (containment 2, icontasks) which is out of scope here.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # KDE's clipboard applet opened a history picker; the equivalent here is the
  # cliphist+fuzzel script already declared in clipboard.nix and bound to
  # Mod+Shift+C. Resolved out of home.packages by name rather than re-declaring
  # the pipeline, so the picker keeps living in exactly one place and the bar
  # button and the keybind can never drift apart.
  clipboardHistory =
    lib.getExe'
    (lib.findSingle
      (p: (lib.getName p) == "clipboard-history")
      (throw "waybar: clipboard-history not found in home.packages (clipboard.nix)")
      (throw "waybar: more than one clipboard-history in home.packages")
      config.home.packages)
    "clipboard-history";

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

  # swaync's client, resolved once here because the notification module needs it
  # three times over (the watcher plus two click handlers). Bare `swaync-client`
  # would depend on whatever PATH the waybar unit inherits, and the upstream
  # snippet's `which swaync-client` guard is the same bet - the store path is
  # the only spelling that cannot go missing between build and run.
  #
  # Read off `config.services.swaync.package` rather than `pkgs.swaynotification
  # center` so the bar and the daemon can never point at two different builds:
  # notifications.nix owns that choice, and this follows it.
  swayncClient = lib.getExe' config.services.swaync.package "swaync-client";

  # KDE's weather applet (54) ran provider `bbcukmet` against
  # `Kuala Lumpur, Malaysia, MY|1735161` with showTemperatureInCompactMode=true
  # and temperatureUnit=6001 (Celsius). It appeared TWICE in KDE - once on the
  # panel proper and once inside the system tray (appletsrc :166-172) - and is
  # ported ONCE here, de-duplicated, because two copies of the same 15-minute
  # poll is redundant rather than faithful.
  #
  # Kuala Lumpur is deliberate and predates the system timezone: locale.nix
  # sets Asia/Singapore, which disagrees with the city. The KDE applet is the
  # parity target, so the city wins and the timezone is only passed to the API
  # so the observation timestamp reads in local time.
  #
  # Waybar has no native weather module, so this is a `custom` module. Provider
  # is Open-Meteo: keyless (no account, no token - the repo's no-plaintext-
  # secrets rule means a key would have to go through sops-nix, and needing
  # none is better), structured JSON so jq parsing is deterministic instead of
  # scraping a text format, and it takes coordinates directly so there is no
  # geocoding round-trip.
  #
  # The JSON contract is non-negotiable: waybar's return-type=json parses this
  # stdout on every tick, and ONE malformed line silently kills the module. So
  # every failure path - DNS, timeout, HTTP error, absent fields, bad types -
  # routes through `fallback`, and the success line is assembled BY jq (--arg,
  # not string interpolation) so quoting and newline escaping cannot be got
  # wrong by hand.
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
    fields=$(printf '%s' "$raw" | ${pkgs.jq}/bin/jq -er '
      .current as $c
      | if ($c.temperature_2m | type) != "number"
           or ($c.weather_code | type) != "number"
        then error("open-meteo: current fields missing or not numeric")
        else "\($c.temperature_2m | round)\t\($c.weather_code)\t\($c.time)"
        end
    ') || fallback

    IFS="$(printf '\t')" read -r temp code obstime <<< "$fields" || fallback
    [ -n "$temp" ] && [ -n "$code" ] || fallback

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
      # Weather sits immediately after the clock, which is where KDE's
      # AppletOrder put it (digitalclock, then weather, then the second
      # spacer) - so modules-center is the position-faithful home for it
      # rather than modules-right.
      modules-center = ["clock" "custom/weather"];
      modules-right = [
        "group/tray-drawer"
        "pulseaudio"
        "battery"
        "cpu"
        "temperature"
        "network"
        # KDE's AppletOrder ran tray(36), battery(63), notifications(35), then
        # the end-of-panel widgets peek(66)/colorizer(56). The relative order
        # battery -> notification -> session is what carries across, so the
        # bell sits last before custom/power rather than splitting the
        # battery/cpu/temperature/network sensor cluster in half.
        "custom/notification"
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

      # The weather module proper; the script and the KDE provenance are
      # documented at the weatherScript binding at the top of this file.
      #
      # interval = 900 matches the `interval: 900` Open-Meteo reports in its own
      # `current` block - the upstream data does not refresh faster than that,
      # so polling harder would only cost requests. Open-Meteo's free tier asks
      # for non-commercial politeness rather than enforcing a rate limit, which
      # makes restraint the whole contract.
      #
      # return-type = "json" is what makes waybar read text/tooltip/class out
      # of the script's stdout instead of treating the line as literal text.
      # tooltip is left ON (unlike the static buttons here) because the script
      # supplies one.
      "custom/weather" = {
        return-type = "json";
        interval = 900;
        exec = "${weatherScript}";
        # The script emits Pango-safe plain text, and its tooltip carries no
        # markup, so waybar must not try to parse the description as markup.
        escape = true;
      };

      # KDE's notification applet (35), which sat between the battery (63) and
      # the session end of AppletOrder - hence the position in modules-right
      # above. swaync replaced mako in notifications.nix precisely so this
      # indicator could exist: unread count, DND toggle, and a history panel.
      #
      # This is swaync's OWN documented waybar snippet (swaync(1), "Waybar
      # Example"), with the bare `swaync-client` substituted for the store path
      # bound at the top of this file. `-swb` is the long-running watcher: it
      # prints one JSON line per state change rather than exiting, so there is
      # deliberately NO `interval` - waybar keeps the process alive and reads
      # stdout as it arrives.
      #
      # The upstream snippet's `exec-if = "which swaync-client"` is dropped, not
      # forgotten. It exists to stop the module when the binary is absent from
      # PATH; a store path cannot be absent, and keeping it would spawn a `which`
      # on every tick to answer a question already settled at build time.
      #
      # The eight format-icons keys are the complete set - the 2x2x2 product of
      # {dnd,-} x {inhibited,-} x {notification,none}. There is no ninth, and
      # the same eight strings are also the CSS classes the client emits, which
      # is what the #custom-notification rules below key on.
      #
      # Glyphs, confirmed by NAME in the font's cmap rather than by codepoint:
      # 󰂚 U+F009A md-bell (unread), 󰂜 U+F009C md-bell_outline (clear),
      # 󰂛 U+F009B md-bell_off (DND), 󰂠 U+F00A0 md-bell_sleep (inhibited).
      # Upstream wrapped its "unread" glyph in a red <span> superscript; that
      # colour lives in the stylesheet here instead, so the palette stays in
      # one place and `escape = true` can stay on.
      "custom/notification" = {
        return-type = "json";
        exec = "${swayncClient} -swb";
        # Left click opens the control centre, right click toggles DND - the
        # same two gestures KDE's applet had. `-sw` makes the client skip
        # waiting for a reply, so a click cannot block the bar's event loop.
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
        # The client's JSON carries the unread count in `text`, which waybar
        # would otherwise treat as Pango markup.
        escape = true;
        # Off per upstream: the count is already the glyph's whole meaning, and
        # the panel one click away carries the actual notification text.
        tooltip = false;
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

      # KDE's system tray (applet 36) split its members into a shown set
      # (blueman, networkmanagement) and a hidden set behind the expand arrow,
      # with scaleIconsToFit=true. Waybar's tray module CANNOT do that split:
      # it has no per-item show/hide, no persistence of which item is hidden,
      # and no arrow of its own. That per-item behaviour is dropped for good
      # (recorded in the parity ledger, todo 18).
      #
      # The closest analogue is a group with a `drawer`: the FIRST module in
      # `modules` is the group leader and is always visible, every later module
      # is hidden until revealed. click-to-reveal = true is deliberate - KDE
      # required a click on the arrow, and hover-reveal would make the bar
      # twitch whenever the pointer crossed it.
      #
      # Leader is `tray` itself, so real SNI items stay permanently visible the
      # way KDE's shown set was. The revealed children are the secondary
      # indicators KDE also kept inside that tray: input method (niri/language
      # = the kimpanel member) and brightness (backlight = the kscreen/
      # brightness member). Todo 12 adds bluetooth/mpris/clipboard/privacy to
      # this same `modules` list; nothing else needs to change to accept them.
      "group/tray-drawer" = {
        orientation = "inherit";
        drawer = {
          transition-duration = 500;
          # Set explicitly. waybar-styles(5) documents the default as "hidden",
          # but src/group.cpp:60 actually defaults it to "drawer-child" - the
          # man page is wrong, so relying on either spelling is a silent CSS
          # miss. The name below is what the style block targets.
          children-class = "tray-drawer-child";
          click-to-reveal = true;
        };
        modules = [
          "tray"
          "niri/language"
          "backlight"
          "bluetooth"
          "mpris"
          "custom/clipboard"
          "privacy"
        ];
      };

      tray = {
        spacing = 8;
        # The bar is 32px tall; 20 leaves 6px of breathing room top and bottom
        # so icons do not touch the panel edges. This is the honest stand-in
        # for KDE's scaleIconsToFit=true, which waybar has no equivalent for.
        icon-size = 20;
        # KDE showed passive members (its shown set included items sitting
        # idle), and the default false would silently swallow any SNI item that
        # reports Passive rather than Active - which reads as "my tray icon
        # vanished". Explicit true keeps the tray's contents predictable.
        show-passive-items = true;
      };

      # KDE kept blueman in its tray's SHOWN set. blueman itself was rejected
      # for this host (hardware/zephyrus/bluetooth.nix:12-13), so the click
      # target is overskride, which is already installed and already floated by
      # a window rule in settings.nix - the same treatment wiremix and impala
      # get, so every bar-launched GUI behaves alike.
      #
      # `controller` is deliberately absent. The man page recommends it only
      # when more than one controller exists; this machine has exactly one, so
      # naming it would just be a string that can go stale. (Note the module
      # reads the alias, not the adapter path - so a wrong value silently
      # selects nothing rather than erroring.)
      #
      # One format per documented state so the glyph alone says which state the
      # adapter is in, before any CSS colour lands: 󰂲 U+F00B2 md-bluetooth_off
      # for off/disabled, 󰂯 U+F00AF md-bluetooth for on-but-idle, 󰂱 U+F00B1
      # md-bluetooth_connect plus a count for connected. format-disabled is set
      # rather than left empty, because an empty format HIDES the module and a
      # silently missing indicator is worse than a struck-through one.
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
        tooltip-format-connected = "{controller_alias}\n{num_connections} connected\n\n{device_enumerate}";
        tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
        tooltip-format-enumerate-connected-battery = "{device_alias}\t{device_battery_percentage}%";
        on-click = "${pkgs.overskride}/bin/overskride";
      };

      # KDE's mediacontroller applet. `player = "playerctld"` is the documented
      # default, but it is written out explicitly because it is load-bearing
      # here: playerctld already runs as a user service
      # (modules/services/home/playerctld.nix:2) and following the *active*
      # player is the whole point - pinning a single player name would make the
      # module go blank whenever anything else took over playback.
      #
      # The default format is "{player} ({status}) {dynamic}", which wastes bar
      # width on the player's own name. {status_icon} + {dynamic} is the same
      # information in one glyph. Glyphs: 󰐊 U+F040A md-play, 󰏤 U+F03E4 md-pause,
      # 󰓛 U+F04DB md-stop, 󰝚 U+F075A md-music.
      #
      # Lengths are capped because the bar is shared with a 60-char window
      # title: the module truncates its own text rather than pushing the rest
      # of the bar around when a long track title arrives. album is dropped
      # from dynamic-order (absence = force exclusion) since title + artist is
      # what KDE's compact applet showed. enable-tooltip-len-limits is left at
      # its default false so the tooltip carries the untruncated text.
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

      # KDE's cameraindicator. `modules` is set EXPLICITLY to screenshare only.
      # The documented default is [{"type":"screenshare"},{"type":"audio-in"}],
      # so leaving it out would silently add a microphone indicator this panel
      # never had in KDE - unrequested scope, and the kind of thing that only
      # shows up the first time something opens the mic. audio-out is likewise
      # omitted: pulseaudio above already covers output.
      #
      # This module is invisible until something actually captures the screen,
      # which is the intended behaviour (KDE's indicator worked the same way) -
      # an empty slot in the drawer is not a fault.
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

    # Catppuccin Mocha, matching foot and fuzzel.
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
         appearance: todo 17 established that niri-flake's typed layer-rules
         schema cannot express blur, so nothing will ever be composited behind
         this. Keep the alpha below 1.0.

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
      #cpu,
      #temperature,
      #network,
      #language,
      #tray {
        padding: 0 10px;
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

         `margin: 6px 0` is what makes it read as a separator rather than a
         frame - it shortens the 32px border to 20px, the same trick as KDE's
         `lengthSeparator=80`. The colour is the translucent surface1 used by
         the bar's bottom edge, so every line in this sheet matches.
         =================================================================== */
      #pulseaudio,
      #cpu,
      #custom-notification {
        border-left: 1px solid rgba(69, 71, 90, 0.6);
        margin: 6px 0;
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

      /* Disconnected is the module's own class. Dimmed rather than red: on a
         laptop that is an ordinary state, and the glyph already changes to
         󰖪. */
      #network.disconnected {
        color: #6c7086;
      }

      /* ===================================================================
         Clickable affordance.

         KDE's applets all highlighted under the pointer, and that is the only
         cue a module does something when pointed at - waybar draws no button
         chrome of its own. Every module listed here really is interactive:
         #clock through its `actions` block, #pulseaudio/#network/#bluetooth
         through `on-click`, and #pulseaudio/#backlight additionally through the
         scroll handling those two modules implement natively.

         #battery, #window, #cpu, #temperature and #custom-weather are
         deliberately absent - none of them has an action, so highlighting them
         would advertise a click that does nothing. The fill animates via the
         global transition. */
      #clock:hover,
      #pulseaudio:hover,
      #network:hover,
      #bluetooth:hover,
      #backlight:hover {
        background: #45475a;
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

      /* The todo-12 indicator cluster. These all live inside the drawer, so
         .tray-drawer-child already gives them padding and the dimmed #a6adc8;
         the rules below only add what is specific to each one. Every selector
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

      #custom-notification:hover {
        background: #45475a;
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
