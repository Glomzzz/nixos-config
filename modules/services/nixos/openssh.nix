{
  lib,
  username,
  ...
}: let
  authorizedKeys = import (../../../users + "/${username}/ssh/authorized-keys.nix");
  hasAuthorizedKeys = authorizedKeys != [];
in {
  warnings =
    lib.optional (!hasAuthorizedKeys)
    "OpenSSH password authentication remains enabled because ${username}'s authorized-keys.nix is empty.";

  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PermitRootLogin = "no";
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = !hasAuthorizedKeys;
    };
  };

  users.users.${username}.openssh.authorizedKeys.keys = authorizedKeys;
}
