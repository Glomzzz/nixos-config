{ ...} : {
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
  hardware.pulseaudio.enable = false;
  

}