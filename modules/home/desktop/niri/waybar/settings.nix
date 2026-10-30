{
  config,
  lib,
  pkgs,
  helpers,
}: let
  clipboardHistory =
    lib.getExe'
    (lib.findSingle
      (p: (lib.getName p) == "clipboard-history")
      (throw "waybar: clipboard-history not found in home.packages (clipboard.nix)")
      (throw "waybar: more than one clipboard-history in home.packages")
      config.home.packages)
    "clipboard-history";
  appLauncher =
    lib.getExe'
    (lib.findSingle
      (p: (lib.getName p) == "app-launcher")
      (throw "waybar: app-launcher not found in home.packages (fuzzel.nix)")
      (throw "waybar: more than one app-launcher in home.packages")
      config.home.packages)
    "app-launcher";
  swayncClient = lib.getExe' config.services.swaync.package "swaync-client";
  networkEditor = lib.getExe' config.services.network-manager-applet.package "nm-connection-editor";
  bluetoothManager = lib.getExe' config.services.blueman-applet.package "blueman-manager";
  # Audio and Bluetooth apps are single-instance GApplications. A plain launch
  # from Waybar forwards the activation to the running copy without an
  # activation token, so niri ignores it when that window sits on another
  # workspace: the click looks dead and the user clicks again. Spawning through
  # niri attaches a token, and niri focuses the existing window instead.
  niriSpawn = "${pkgs.niri}/bin/niri msg action spawn --";
  inherit (helpers) powerMenu setProfile idleInhibit weatherScript netspeed;
in {
  layer = "top";
  position = "top";
  height = 32;
  spacing = 6;

  modules-left = ["custom/launcher" "niri/workspaces" "niri/window"];
  modules-center = ["clock" "custom/weather"];
  # Keep Bluetooth here, not also in the tray drawer: duplicate membership
  # would instantiate two indicators and two D-Bus watchers.
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
    on-click = appLauncher;
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
    exec = "${weatherScript}/bin/waybar-weather";
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
    on-click = "${niriSpawn} ${lib.getExe pkgs.pwvucontrol}";
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
      lock = "${config.programs.swaylock.package}/bin/swaylock -f";
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

  # Keep the speed/connection readout; its click opens the GTK profile editor.
  # Wi-Fi selection and password prompts live in nm-applet's tray menu.
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
    on-click = networkEditor;
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
    on-click = "${niriSpawn} ${bluetoothManager}";
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
}
