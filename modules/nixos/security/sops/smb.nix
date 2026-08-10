{config, ...}: {
  # macOS refuses guest SMB logins even on shares flagged for guest access
  # (session setup fails with NT_STATUS_ACCOUNT_RESTRICTION), so the mount in
  # modules/services/nixos/smb.nix needs a real account. mount.cifs only reads
  # credentials from a file, never from the option string, hence the template.
  sops.secrets = {
    "smb/mac-mini/username" = {};
    "smb/mac-mini/password" = {};
  };

  # Rendered at activation, owned by root with mode 0400 by default. Only
  # mount.cifs (which runs as root from the automount unit) ever reads it, so
  # the password never lands in a world-readable mount option or in the
  # /proc/mounts line.
  sops.templates."smb-mac-mini-credentials".content = ''
    username=${config.sops.placeholder."smb/mac-mini/username"}
    password=${config.sops.placeholder."smb/mac-mini/password"}
  '';
}
