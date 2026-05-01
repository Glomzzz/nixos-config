{ config, pkgs, lib, ... }: {
  # Enable libinput for mouse/touchpad support
  services.libinput.enable = true;
  
  # Ensure X11 has proper input drivers
  services.xserver.libinput.enable = true;
  
  # Additional input packages
  environment.systemPackages = with pkgs; [
    libinput
    xorg.xf86inputlibinput
  ];
}
