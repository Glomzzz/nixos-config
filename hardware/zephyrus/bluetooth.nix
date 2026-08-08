_: {
  # Bluetooth support
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
      };
    };
  };
  # No blueman: overskride (in the niri desktop module) is the Bluetooth GUI,
  # and running two tray applets against the same adapter fights over pairing.
}
