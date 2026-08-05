{pkgs, ...}: {
  programs.obs-studio.enable = true;

  home.packages = with pkgs; [
    alsa-utils
    easyeffects
    ffmpeg
    gimp3
    pavucontrol
    qpwgraph
    vlc
  ];
}
