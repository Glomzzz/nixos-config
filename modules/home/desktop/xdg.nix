{pkgs, ...}: let
  python = pkgs.python3.withPackages (pythonPackages: [pythonPackages.dbus-next]);
  yaziFileManager1 = pkgs.writeTextFile {
    name = "yazi-file-manager1";
    destination = "/bin/yazi-file-manager1";
    executable = true;
    text = ''
      #!${python}/bin/python3

      import asyncio
      import os
      import sys
      from urllib.parse import unquote_to_bytes, urlsplit

      from dbus_next.aio import MessageBus
      from dbus_next.service import ServiceInterface, method


      TERMINAL = "${pkgs.xdg-terminal-exec}/bin/xdg-terminal-exec"
      YAZI = "${pkgs.yazi}/bin/yazi"
      tasks = set()


      def local_path(uri):
          parsed = urlsplit(uri)
          if parsed.scheme != "file" or parsed.netloc not in ("", "localhost"):
              return None
          return os.fsdecode(unquote_to_bytes(parsed.path))


      async def launch_yazi(paths):
          try:
              process = await asyncio.create_subprocess_exec(
                  TERMINAL,
                  "--app-id=yazi",
                  "--title=Yazi",
                  "--",
                  YAZI,
                  *paths,
                  start_new_session=True,
              )
              await process.wait()
          except OSError as error:
              print(f"yazi-file-manager1: {error}", file=sys.stderr)


      class FileManager1(ServiceInterface):
          def __init__(self):
              super().__init__("org.freedesktop.FileManager1")

          def open(self, uris):
              paths = [path for uri in uris if (path := local_path(uri)) is not None]
              if not paths:
                  return

              task = asyncio.create_task(launch_yazi(paths))
              tasks.add(task)
              task.add_done_callback(tasks.discard)

          @method()
          def ShowFolders(self, uris: "as", startup_id: "s"):
              self.open(uris)

          @method()
          def ShowItems(self, uris: "as", startup_id: "s"):
              self.open(uris)

          @method()
          def ShowItemProperties(self, uris: "as", startup_id: "s"):
              self.open(uris)


      async def main():
          bus = await MessageBus().connect()
          bus.export("/org/freedesktop/FileManager1", FileManager1())
          await bus.request_name("org.freedesktop.FileManager1")
          await bus.wait_for_disconnect()


      if __name__ == "__main__":
          asyncio.run(main())
    '';
  };
in {
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

    # yazi.desktop carries Terminal=true, so glib needs a terminal provider for
    # ordinary directory launches. foot.desktop is used rather than the client
    # because no foot server runs in this session.
    terminal-exec = {
      enable = true;
      settings.default = ["foot.desktop"];
    };

    # Firefox reveals downloads through FileManager1.ShowItems. Its fallback
    # opens only the parent directory, which discards the item URI and leaves
    # yazi unable to hover the requested file. This activatable bridge preserves
    # that URI and passes the file itself to yazi as its current entry.
    dataFile."dbus-1/services/org.freedesktop.FileManager1.service".text = ''
      [D-BUS Service]
      Name=org.freedesktop.FileManager1
      Exec=${yaziFileManager1}/bin/yazi-file-manager1
    '';
  };

  home.packages = with pkgs; [
    xdg-utils
    handlr
  ];
}
