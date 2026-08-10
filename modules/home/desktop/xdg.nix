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

    # yazi.desktop carries Terminal=true, and glib has to find a terminal
    # itself before it can honour the inode/directory association above.
    # gdesktopappinfo.c looks for `xdg-terminal-exec` first and only then falls
    # back to a hardcoded list (gnome-terminal, konsole, xterm, ...), none of
    # which is installed here - so every directory launch died with
    # "Unable to find terminal required for application" and nothing appeared.
    #
    # That is the failure behind Firefox's "Open Containing Folder" doing
    # nothing: Firefox first calls org.freedesktop.FileManager1.ShowItems, and
    # when that name is not activatable (no GUI file manager on this host) it
    # falls back to launching the parent directory through
    # g_app_info_launch_default_for_uri, which is exactly the path that needs a
    # terminal. The fallback only logs a g_warning on failure, so the click
    # looked like a no-op.
    #
    # foot.desktop, not footclient.desktop: no foot server runs in this session,
    # and xdg-terminal-exec's own low-priority list already excludes the client.
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
