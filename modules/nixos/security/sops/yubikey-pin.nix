{
  hostname,
  lib,
  username,
  ...
}: let
  secretFile = ../../../../secrets/hosts + "/${hostname}-yubikey-pin.yaml";
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
