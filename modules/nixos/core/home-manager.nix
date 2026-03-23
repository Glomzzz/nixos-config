{
  inputs,
  specialArgs,
  username,
  ...
}:
let
  userRoot = ../../../users + "/${username}";
in
{
  home-manager.backupFileExtension = "hm-backup";

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.${username} = import (userRoot + "/home.nix");
  home-manager.extraSpecialArgs = inputs // specialArgs;
}
