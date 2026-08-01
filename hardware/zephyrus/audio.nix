_: {
  services.pipewire = {
    enable = true;
    audio.enable = true;
    pulse.enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };
    jack.enable = true;
    extraConfig = {
      pipewire."92-audio-quality" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
          "default.clock.allowed-rates" = [
            44100
            48000
            88200
            96000
          ];
          "default.clock.quantum" = 1024;
          "default.clock.min-quantum" = 256;
          "default.clock.max-quantum" = 2048;
        };
      };
      client."92-audio-quality" = {
        "stream.properties" = {
          "resample.quality" = 10;
          "channelmix.normalize" = false;
          "channelmix.mix-lfe" = true;
        };
      };
      pipewire-pulse."92-audio-quality" = {
        "stream.properties" = {
          "resample.quality" = 10;
          "channelmix.normalize" = false;
          "channelmix.mix-lfe" = true;
        };
      };
    };
  };
  security.rtkit.enable = true;
  services.pulseaudio.enable = false;
}
