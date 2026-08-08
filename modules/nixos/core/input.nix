{pkgs, ...}: {
  # Caps Lock is a second Ctrl everywhere. This xkb block is the source for the
  # virtual consoles and the greetd/tuigreet login prompt (via
  # console.useXkbConfig); the niri session sets the same option itself in
  # modules/home/desktop/niri/settings.nix because a Wayland compositor does
  # not read these.
  services.xserver.xkb = {
    layout = "us";
    options = "ctrl:nocaps";
  };

  console.useXkbConfig = true;

  # Enable libinput for mouse/touchpad support
  services.libinput = {
    enable = true;
    mouse = {
      # Ensure mice are fully enabled
      sendEventsMode = "enabled";
      # Disable acceleration for consistent behavior
      accelProfile = "flat";
    };
    touchpad = {
      # Natural scrolling for touchpad
      naturalScrolling = true;
      tapping = true;
    };
  };

  # Additional input packages and tools
  environment.systemPackages = with pkgs; [
    libinput
    xf86-input-libinput
    # Diagnostic tools
    evtest
    # Wireless receiver diagnostics
    solaar
  ];
}
