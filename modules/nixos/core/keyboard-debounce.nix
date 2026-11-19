{pkgs, ...}: let
  # The Z key's switch bounces and sends extra presses. This filter sits
  # between intercept and uinput for each keyboard with a Z key, and holds a
  # Z change back until it has been stable for 30 ms. See
  # keyboard-z-debounce.py for the rule and its tests.
  zDebounce = pkgs.writers.writePython3Bin "keyboard-z-debounce" {} (builtins.readFile ./keyboard-z-debounce.py);
in {
  services.interception-tools = {
    enable = true;
    # Replaces the default caps2esc plugin, which this config does not use.
    plugins = [zDebounce];
    udevmonConfig = ''
      - JOB: "intercept -g $DEVNODE | keyboard-z-debounce | uinput -d $DEVNODE"
        DEVICE:
          EVENTS:
            EV_KEY: [KEY_Z]
    '';
  };
}
