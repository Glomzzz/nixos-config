_: {
  # Bluetooth support
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    # BlueZ enables its supported profiles by default. General.Enable is not
    # a supported main.conf key and only produces a startup warning.
  };
}
