{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    wget
    curl
    sysstat
    lm_sensors
    input-remapper
    libevdev
    python313Packages.libevdev
  ];
}
