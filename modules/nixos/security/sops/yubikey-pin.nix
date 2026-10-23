{
  hostname,
  lib,
  secretFiles,
  username,
  ...
}: let
  secretFile = secretFiles.hosts."${hostname}-yubikey-pin";
in
  # Permit building the provisioning command before the PIN has been enrolled.
  lib.mkIf (builtins.pathExists secretFile) {
    sops.secrets."yubikey/openpgp-user-pin" = {
      sopsFile = secretFile;
      key = "openpgp_user_pin";
      owner = username;
      mode = "0400";
    };
  }
