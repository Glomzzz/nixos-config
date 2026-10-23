{
  config,
  lib,
  pkgs,
  secretFiles,
  username,
  ...
}: let
  credentials = import ./package.nix {
    inherit pkgs;
    secretsFile = secretFiles.users.${username};
  };
in {
  home.packages = [credentials pkgs.sops];

  # Remove only the old recoverable password cache, never the VFS cache:
  # it may contain dirty writes that have not reached the server yet.
  home.activation.removeLegacySmbCredentialCache = lib.hm.dag.entryAfter ["writeBoundary"] ''
    run rm -f -- ${lib.escapeShellArg "${config.xdg.cacheHome}/rclone/mac-mini/smb-credentials"}
  '';
}
