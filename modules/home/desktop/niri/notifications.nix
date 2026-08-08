{pkgs, ...}: {
  # swaync (SwayNotificationCenter) replaces mako here. mako is a popup-only
  # daemon: once a notification times out it is gone, there is no history, no
  # unread count, and no do-not-disturb toggle. The KDE panel this config is
  # reproducing had all three (a notification centre with a persistent list, a
  # tray badge showing unread count, and a DND switch), so mako cannot reach
  # parity no matter how it is styled.
  #
  # swaync is still a native Wayland (wlr-layer-shell) daemon, still has a real
  # Home Manager module, and still registers org.freedesktop.Notifications - but
  # it adds the control centre, grouping, relative timestamps and DND that the
  # bar's custom/notification module drives via `swaync-client` (see the
  # `custom/notification` block in waybar.nix, which reads `swaync-client -swb`
  # for the unread count and toggles the panel and DND on click).
  #
  # Activation: the Home Manager module writes a `Type = "dbus"` user unit with
  # `BusName = org.freedesktop.Notifications`, bound to graphical-session.target.
  # That is the same bus name mako owned, and only one process can own it, which
  # is why the mako block is removed in the same change rather than disabled.
  services.swaync = {
    enable = true;
    package = pkgs.swaynotificationcenter;

    # -> $XDG_CONFIG_HOME/swaync/config.json
    #
    # Only behavioural/geometry keys live here. Every colour, border, radius,
    # font and padding mako expressed as a setting has no config.json
    # equivalent in swaync and is ported to style.css below.
    settings = {
      # mako: anchor = "top-right", layer = "overlay".
      positionX = "right";
      positionY = "top";
      layer = "overlay";
      layer-shell = true;
      control-center-layer = "top";

      # Let style.css win over the ambient GTK theme, the way mako's own
      # settings did (mako never consulted GTK at all).
      ignore-gtk-theme = true;
      cssPriority = "user";

      # mako: margin = "12". swaync has no popup margin key; the control centre
      # has its own, so the 12px gap is applied there and to the popup via the
      # `.notification-background` padding in style.css.
      control-center-margin-top = 12;
      control-center-margin-bottom = 12;
      control-center-margin-right = 12;
      control-center-margin-left = 12;

      # mako: width = 380.
      notification-window-width = 380;
      # mako's `height = 160` was a per-notification MAXIMUM. swaync's
      # equivalent key sizes the whole popup stack, so clamping it to 160 would
      # truncate the second and later notifications. -1 = fit to content, which
      # is the faithful port of "as tall as it needs to be, up to a limit".
      notification-window-height = -1;

      # TIMEOUTS ARE SECONDS HERE, MILLISECONDS IN MAKO.
      # mako default-timeout 6000 ms -> 6 s
      # mako "urgency=low"  timeout 4000 ms -> 4 s
      # mako "urgency=critical" timeout 0 -> 0, which means "never auto-dismiss"
      # in both tools, so that one value carries across unchanged.
      timeout = 6;
      timeout-low = 4;
      timeout-critical = 0;

      # mako: icons = true. `max-icon-size = 48` is NOT set here - swaync's
      # `notification-icon-size` key is deprecated in its own schema; the size
      # is the `--notification-icon-size` CSS variable in style.css instead.
      image-visibility = "when-available";

      # mako: actions = true. mako: markup = true has no key because swaync
      # always renders Pango markup in the body.
      notification-2fa-action = true;
      notification-inline-replies = false;

      # mako: ignore-timeout = false, i.e. an application's requested timeout is
      # honoured. swaync has no inverse switch; it honours the hint by default.

      # Control centre - the part mako had no equivalent for at all.
      control-center-width = 420;
      control-center-height = 600;
      fit-to-screen = true;
      notification-grouping = true;
      relative-timestamps = true;
      keyboard-shortcuts = true;
      hide-on-clear = false;
      hide-on-action = true;
      transition-time = 200;
      text-empty = "No Notifications";
      widgets = ["title" "dnd" "notifications"];
      widget-config = {
        title = {
          text = "Notifications";
          clear-all-button = true;
          button-text = "Clear All";
        };
        dnd = {
          text = "Do Not Disturb";
        };
        notifications = {
          vexpand = true;
        };
      };
    };

    # -> $XDG_CONFIG_HOME/swaync/style.css
    #
    # Catppuccin Mocha, matching foot/fuzzel/waybar. Everything in here is a
    # mako setting that has no config.json counterpart: font, padding,
    # border-size, border-radius, background-color, text-color, border-color,
    # progress-color, and the per-urgency border colours.
    #
    # Selectors are the ones in swaync 0.12.6's own shipped
    # /etc/xdg/swaync/style.css - the popup card is
    # `.notification-row .notification-background .notification`, and urgency is
    # a class on that same node (`.low` / `.normal` / `.critical`).
    style = ''
      :root {
        /* mako max-icon-size = 48 (the deprecated notification-icon-size key). */
        --notification-icon-size: 48px;
        --notification-app-icon-size: calc(var(--notification-icon-size) / 3);
        --notification-group-icon-size: 32px;

        /* mako background-color = "#1e1e2eee" (0xee alpha = 0.93). */
        --mocha-base-alpha: rgba(30, 30, 46, 0.93);
        --mocha-base: #1e1e2e;
        --mocha-surface0: #45475a;
        --mocha-surface1: #585b70;
        --mocha-overlay0: #6c7086;
        --mocha-text: #cdd6f4;
        --mocha-subtext0: #a6adc8;
        --mocha-blue: #89b4fa;
        --mocha-red: #f38ba8;
      }

      * {
        font-family: "JetBrainsMono Nerd Font";
        font-size: 11pt;
      }

      notificationwindow,
      blankwindow {
        background: transparent;
      }

      /* mako margin = "12": the gap between the popup and the screen edge. */
      .notification-row .notification-background {
        padding: 12px;
      }

      /* The popup card itself: mako border-size = 2, border-radius = 8,
         background-color = "#1e1e2eee", border-color = "#89b4fa". */
      .notification-row .notification-background .notification {
        background: rgba(30, 30, 46, 0.93);
        border: 2px solid #89b4fa;
        border-radius: 8px;
        padding: 0;
      }

      /* mako "urgency=low" -> border-color = "#6c7086". */
      .notification-row .notification-background .notification.low {
        border-color: #6c7086;
      }

      .notification-row .notification-background .notification.normal {
        border-color: #89b4fa;
      }

      /* mako "urgency=critical" -> border-color = "#f38ba8". The never-expire
         half of that rule is settings.timeout-critical = 0. */
      .notification-row .notification-background .notification.critical {
        border-color: #f38ba8;
      }

      /* mako padding = "12". */
      .notification-row
        .notification-background
        .notification
        .notification-default-action {
        padding: 12px;
        margin: 0;
        background: transparent;
        border: none;
        box-shadow: none;
      }

      .notification-row
        .notification-background
        .notification
        .notification-default-action:hover {
        background: rgba(69, 71, 90, 0.6);
      }

      /* mako text-color = "#cdd6f4". */
      .notification-row .notification-background .notification label {
        color: #cdd6f4;
      }

      .notification-row
        .notification-background
        .notification
        .notification-content
        .summary {
        color: #cdd6f4;
        font-weight: bold;
      }

      .notification-row
        .notification-background
        .notification
        .notification-content
        .body {
        color: #cdd6f4;
      }

      .notification-row
        .notification-background
        .notification
        .notification-content
        .time {
        color: #a6adc8;
      }

      /* mako progress-color = "over #45475a". */
      .notification-row
        .notification-background
        .notification
        .notification-content
        progressbar,
      .notification-row
        .notification-background
        .notification
        .notification-content
        progressbar trough,
      .notification-row
        .notification-background
        .notification
        .notification-content
        progressbar progress {
        background: #45475a;
      }

      .notification-row
        .notification-background
        .notification
        .notification-action > button {
        background: #45475a;
        color: #cdd6f4;
        border: none;
        border-radius: 8px;
        margin: 4px;
        padding: 4px 8px;
      }

      .notification-row
        .notification-background
        .notification
        .notification-action > button:hover {
        background: #585b70;
      }

      .close-button {
        background: #45475a;
        color: #cdd6f4;
        border: none;
        border-radius: 100%;
        box-shadow: none;
        margin-top: 16px;
        margin-right: 16px;
        min-width: 24px;
        min-height: 24px;
        padding: 0;
      }

      .close-button:hover {
        background: #f38ba8;
        color: #1e1e2e;
      }

      /* Grouped notifications carry urgency on the group node too. */
      .notification-group {
        border-radius: 8px;
      }

      .notification-group.low {
        border-color: #6c7086;
      }

      .notification-group.normal {
        border-color: #89b4fa;
      }

      .notification-group.critical {
        border-color: #f38ba8;
      }

      .notification-group .notification-group-headers label {
        color: #cdd6f4;
      }

      /* The control centre - no mako equivalent, styled to match the popup. */
      .control-center {
        background: rgba(30, 30, 46, 0.93);
        border: 2px solid #89b4fa;
        border-radius: 8px;
        padding: 12px;
      }

      .control-center .control-center-list {
        background: transparent;
      }

      .control-center .control-center-list-placeholder {
        color: #6c7086;
      }

      .blank-window {
        background: transparent;
      }

      .floating-notifications {
        background: transparent;
      }

      .widget-title {
        color: #cdd6f4;
        margin: 8px;
      }

      .widget-title > label {
        color: #cdd6f4;
        font-size: 12pt;
        font-weight: bold;
      }

      .widget-title > button {
        background: #45475a;
        color: #cdd6f4;
        border: none;
        border-radius: 8px;
        padding: 4px 8px;
      }

      .widget-title > button:hover {
        background: #585b70;
      }

      .widget-dnd {
        color: #cdd6f4;
        margin: 8px;
      }

      .widget-dnd label {
        color: #cdd6f4;
      }

      .widget-dnd > switch {
        background: #45475a;
        border: none;
        border-radius: 12px;
        box-shadow: none;
      }

      .widget-dnd > switch:checked {
        background: #89b4fa;
      }

      .widget-dnd > switch slider {
        background: #cdd6f4;
        border-radius: 12px;
      }
    '';
  };

  # notify-send, used by the QA scenarios and by scripts elsewhere in this
  # config. The swaync module already adds the daemon package and at-spi2-core.
  home.packages = [pkgs.libnotify];
}
