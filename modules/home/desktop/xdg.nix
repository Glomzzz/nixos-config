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
        archive = ["org.gnome.FileRoller.desktop"];
        image = ["oculante.desktop"];
        video = ["mpv.desktop"];
        audio = ["mpv.desktop"];
      in {
        # Archives
        "application/zip" = archive;
        "application/x-zip" = archive;
        "application/x-zip-compressed" = archive;

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
      };
    };

    # Supply a Wayland terminal for any desktop entry declaring Terminal=true.
    terminal-exec = {
      enable = true;
      settings.default = ["foot.desktop"];
    };
  };

  home.packages = with pkgs; [
    xdg-utils
    handlr
  ];
}
