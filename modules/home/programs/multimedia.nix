{pkgs, ...}: let
  celluloidMpvConfig = pkgs.writeText "celluloid-mpv.conf" ''
    hwdec=auto-safe
    profile=high-quality
    keep-open=yes
  '';
in {
  programs.obs-studio.enable = true;

  # Celluloid embeds libmpv: retain decoding/quality preferences, but let its
  # GTK render context own video output instead of forcing gpu-next/Vulkan.
  xdg.configFile."celluloid/mpv.conf".source = celluloidMpvConfig;
  dconf.settings."io/github/celluloid-player/celluloid" = {
    mpv-config-enable = true;
    # Celluloid expects a file URI here, not a plain filesystem path.
    mpv-config-file = "file://${celluloidMpvConfig}";
    mpris-enable = true;
  };

  # pwvucontrol lives in desktop/niri/programs.nix. qpwgraph stays because a
  # patchbay is not the same thing as a mixer; EasyEffects supplies the EQ chain.
  home.packages = with pkgs; [
    alsa-utils
    celluloid
    easyeffects
    ffmpeg
    gimp3
    qpwgraph
  ];
}
