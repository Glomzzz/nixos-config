{pkgs, ...}: {
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
    # Support for Logitech wireless devices
    solaar
  ];
}
