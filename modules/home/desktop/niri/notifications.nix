{pkgs, ...}: {
  # `wired` was in the original plan, but it is X11-only: it has no Wayland
  # code at all and links against xlib/xss (winit 0.26, cairo-xlib). Under niri
  # it could only run through xwayland-satellite, where it cannot use
  # wlr-layer-shell to place notifications - so notifications would either not
  # appear or land in the wrong place.
  #
  # mako is the native Wayland equivalent, has a real Home Manager module, and
  # is D-Bus activated (org.freedesktop.Notifications), so it starts on the
  # first notification without a hand-written unit.
  services.mako = {
    enable = true;

    settings = {
      anchor = "top-right";
      layer = "overlay";
      margin = "12";
      padding = "12";
      width = 380;
      height = 160;
      border-size = 2;
      border-radius = 8;
      default-timeout = 6000;
      ignore-timeout = false;
      icons = true;
      max-icon-size = 48;
      markup = true;
      actions = true;
      font = "JetBrainsMono Nerd Font 11";

      # Catppuccin Mocha, matching foot/fuzzel/waybar.
      background-color = "#1e1e2eee";
      text-color = "#cdd6f4";
      border-color = "#89b4fa";
      progress-color = "over #45475a";

      # Sections are keyed by a mako criteria string.
      "urgency=low" = {
        border-color = "#6c7086";
        default-timeout = 4000;
      };

      "urgency=critical" = {
        border-color = "#f38ba8";
        # Critical notifications should not disappear on their own.
        default-timeout = 0;
      };
    };
  };

  home.packages = [pkgs.libnotify];
}
