{pkgs, ...}: {
  programs.obs-studio.enable = true;

  # vlc dropped in favour of mpv (configured in desktop/niri/programs.nix) and
  # pavucontrol dropped in favour of wiremix, so there is one video player and
  # one mixer rather than two of each. qpwgraph stays because a patchbay is not
  # the same thing as a mixer, and easyeffects stays for its EQ chain.
  home.packages = with pkgs; [
    alsa-utils
    easyeffects
    ffmpeg
    gimp3
    qpwgraph
  ];
}
