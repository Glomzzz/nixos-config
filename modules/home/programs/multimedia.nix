{pkgs, ...}: {
  programs.obs-studio.enable = true;

  # mpv and the PipeWire mixer pwvucontrol live in desktop/niri/programs.nix.
  # qpwgraph stays because a patchbay is not the same thing as a mixer, and
  # easyeffects stays for its EQ chain.
  home.packages = with pkgs; [
    alsa-utils
    easyeffects
    ffmpeg
    gimp3
    qpwgraph
  ];
}
