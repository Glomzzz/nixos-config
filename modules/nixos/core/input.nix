{pkgs, ...}: {
  # Enable libinput for mouse/touchpad support
  services.libinput.enable = true;

  # Additional input packages
  environment.systemPackages = with pkgs; [
    libinput
    xf86-input-libinput
  ];
}
