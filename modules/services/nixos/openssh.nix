{
  lib,
  username,
  ...
}: let
  authorizedKeys = import ../../../users/glom/ssh/authorizedKeys.nix;
  hasAuthorizedKeys = authorizedKeys != [];
in {
  warnings = lib.optional (!hasAuthorizedKeys)
    "OpenSSH password authentication remains enabled because users/glom/ssh/authorizedKeys.nix is empty.";

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = !hasAuthorizedKeys;
    };
  };

  users.users.${username}.openssh.authorizedKeys.keys = authorizedKeys;
}
