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
  home = {
    packages = [credentials pkgs.sops];

    activation = {
      # One-time migration of unmanaged Nix settings. Never copy the token into
      # the store or an activation backup; provisioning a read-only token is manual.
      removePersistentNixTokens = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run ${pkgs.python3}/bin/python3 ${../../../../../scripts/remove-nix-access-tokens.py} \
          ${lib.escapeShellArg "${config.xdg.configHome}/nix/nix.conf"}
      '';

      # Remove only the old recoverable password cache, never the VFS cache:
      # it may contain dirty writes that have not reached the server yet.
      removeLegacySmbCredentialCache = lib.hm.dag.entryAfter ["writeBoundary"] ''
        run rm -f -- ${lib.escapeShellArg "${config.xdg.cacheHome}/rclone/mac-mini/smb-credentials"}
      '';
    };
  };
}
