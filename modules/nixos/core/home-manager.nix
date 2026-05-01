{
  inputs,
  specialArgs,
  username,
  ...
}: let
  userRoot = ../../../users + "/${username}";
in {
  home-manager.backupFileExtension = "hm-backup";

  home-manager.useGlobalPkgs = true;

  home-manager.users.${username} = {
    imports = [
      (import (userRoot + "/home.nix"))
      inputs.emacs-config.homeManagerModules.default
    ];
  };
  home-manager.extraSpecialArgs = inputs // specialArgs;
}
