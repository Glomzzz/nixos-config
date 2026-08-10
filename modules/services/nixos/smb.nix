{config, ...}: let
  credentials = config.sops.templates."smb-mac-mini-credentials".path;
  uid = toString config.users.users.glom.uid;
  gid = toString config.users.groups.users.gid;
in {
  # yazi has no VFS of its own - it browses paths - so reaching the mac-mini
  # over SMB means giving the kernel a real mount rather than teaching yazi a
  # protocol. gvfs would also work through `gio mount`, but its shares live
  # under a per-session /run/user/$UID/gvfs path that only exists once a GUI
  # session has authenticated, which is exactly the fragility this avoids.
  boot.supportedFilesystems = ["cifs"]; # pulls in cifs-utils for mount.cifs

  fileSystems."/mnt/mac-mini" = {
    # macOS exposes each local account's home as an implicit share named after
    # the user, which is why this is //mac-mini/glom and not the explicit
    # "Glom's Public Folder" sharepoint (that one only covers ~/Public, and its
    # guest access is unusable - macOS 26 rejects guest logins outright).
    #
    # The hostname resolves through Tailscale (100.64.31.32) via systemd-resolved,
    # so this works off the LAN as well.
    device = "//mac-mini/glom";
    fsType = "cifs";
    options = [
      # Mount lazily on first access and unmount after 10 minutes idle. Without
      # this, a mac-mini that is asleep, off, or off-network makes
      # local-fs.target hang at boot and blocks the login session.
      "noauto"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "x-systemd.mount-timeout=10s"
      # Needs the network (and Tailscale, when off-LAN) to be up first.
      "x-systemd.requires=tailscaled.service"
      "x-systemd.after=network-online.target"

      "credentials=${credentials}"

      # CIFS on a macOS server hands back POSIX-looking ownership that means
      # nothing here, so everything is presented as glom:users instead. Files
      # 0600 / dirs 0700 keeps the mount private to this user.
      "uid=${uid}"
      "gid=${gid}"
      "file_mode=0600"
      "dir_mode=0700"

      # SMB 3.1.1 with encryption in transit - what macOS 26 speaks natively.
      "vers=3.1.1"
      "seal"

      # macOS filenames are UTF-8 NFD; without this, names with CJK or accented
      # characters come back mangled.
      "iocharset=utf8"

      # Drop the connection instead of blocking forever in D state when the
      # mac-mini disappears mid-transfer. yazi (and any shell sitting in the
      # directory) gets an EIO it can recover from.
      "soft"
      "echo_interval=10"
      "actimeo=30"

      # Let a non-root user unmount the share by hand if needed.
      "nofail"
      "user"
    ];
  };

  # The automount unit needs the sops template to exist before the first access,
  # not merely before local-fs.target.
  systemd.automounts = [
    {
      where = "/mnt/mac-mini";
      wantedBy = ["multi-user.target"];
    }
  ];
}
