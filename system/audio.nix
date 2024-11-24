{ pkgs,...} : {
    services.pipewire = {
      enable = true;
      audio.enable = true;
      pulse.enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      jack.enable = true;
  };
  security.rtkit.enable = true;
  
  services.pipewire.wireplumber.extraConfig.bluetoothEnhancements = {
  "monitor.bluez.properties" = {
      "bluez5.enable-sbc-xq" = true;
      "bluez5.enable-msbc" = true;
      "bluez5.enable-hw-volume" = true;
      "bluez5.roles" = [ "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag" ];
      "bluez5.codecs" = [ "ldac" "aptx" "aptx_hd" "aac" "sbc" ];
  };
  };



  hardware.pulseaudio.enable = false;
  # Enable sound with pipewire.
  # hardware.pulseaudio = {
  #   enable = true;
  #   package = pkgs.pulseaudioFull;
  #   configFile = pkgs.writeText "default.pa" ''
  #     load-module module-bluetooth-policy
  #     load-module module-bluetooth-discover
  #     ## module fails to load with 
  #     ##   module-bluez5-device.c: Failed to get device path from module arguments
  #     ##   module.c: Failed to load module "module-bluez5-device" (argument: ""): initialization failed.
  #     # load-module module-bluez5-device
  #     # load-module module-bluez5-discover
  #   '';
  # };
}