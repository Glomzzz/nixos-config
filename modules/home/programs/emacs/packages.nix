{pkgs, ...}: {
  # Runtime helpers for Dirvish previews, plus the Han font the Emacs
  # configuration uses for Chinese text and EPUB body text.
  home.packages = with pkgs; [
    epub-thumbnailer
    ffmpegthumbnailer
    ghostscript
    imagemagick
    libtool
    # Optional kitty-graphics.el can also render in the Foot fallback via Sixel.
    libsixel
    # Configured as the Han fontset family in `modules/ui/appearance.el' and
    # as the `variable-pitch' family for EPUB reading in `reading.el'.
    lxgw-wenkai
    mediainfo
    poppler-utils
    vips
  ];
}
