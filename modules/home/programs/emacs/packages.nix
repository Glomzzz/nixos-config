{pkgs, ...}: {
  # Runtime helpers for Dirvish previews.
  home.packages = with pkgs; [
    epub-thumbnailer
    ffmpegthumbnailer
    ghostscript
    imagemagick
    libtool
    mediainfo
    poppler-utils
    vips
  ];
}
