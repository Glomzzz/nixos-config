{pkgs, ...}: {
  xdg = {
    enable = true;
    userDirs.enable = true;

    # Without KDE there is no central "default applications" dialog, so the
    # associations that Plasma used to own are declared here. Desktop file
    # names were taken from each package's share/applications directory.
    mimeApps = {
      enable = true;

      defaultApplications = let
        pdf = ["org.pwmt.zathura.desktop"];
        image = ["oculante.desktop"];
        video = ["mpv.desktop"];
        audio = ["mpv.desktop"];
      in {
        # Documents
        "application/pdf" = pdf;
        "application/epub+zip" = pdf;
        "application/postscript" = pdf;

        # Images
        "image/png" = image;
        "image/jpeg" = image;
        "image/gif" = image;
        "image/webp" = image;
        "image/svg+xml" = image;
        "image/bmp" = image;
        "image/tiff" = image;

        # Video
        "video/mp4" = video;
        "video/x-matroska" = video;
        "video/webm" = video;
        "video/quicktime" = video;
        "video/x-msvideo" = video;

        # Audio
        "audio/mpeg" = audio;
        "audio/flac" = audio;
        "audio/ogg" = audio;
        "audio/x-wav" = audio;

        # Directories open in yazi, which replaces nemo entirely.
        "inode/directory" = ["yazi.desktop"];
      };
    };
  };

  home.packages = with pkgs; [
    xdg-utils
    handlr
  ];
}
