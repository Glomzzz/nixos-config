{
  config,
  username,
  ...
}: {
  # macOS refuses guest SMB logins even on shares flagged for guest access
  # (session setup fails with NT_STATUS_ACCOUNT_RESTRICTION), so rclone needs a
  # real account for the user-space mount.
  sops.secrets = {
    "smb/mac-mini/username" = {};
    "smb/mac-mini/password" = {};
  };

  # The on-demand Home Manager service runs as the desktop user. Keep its input
  # private and pass only rclone's obscured form to the mount process.
  sops.templates."smb-mac-mini-credentials" = {
    owner = username;
    mode = "0400";
    content = ''
      username=${config.sops.placeholder."smb/mac-mini/username"}
      password=${config.sops.placeholder."smb/mac-mini/password"}
    '';
  };
}
