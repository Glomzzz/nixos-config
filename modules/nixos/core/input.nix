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

  # Keep the ROG Omni receiver awake. It is detected reliably at boot, but
  # the device later disconnects and reconnects on its own.
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="0b05", ATTR{idProduct}=="1ace", TEST=="power/control", ATTR{power/control}="on"
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="0b05", ATTR{idProduct}=="1ace", TEST=="power/autosuspend_delay_ms", ATTR{power/autosuspend_delay_ms}="-1"
  '';

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
