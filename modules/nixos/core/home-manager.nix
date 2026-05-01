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

  # Clean up old hm-backup files before activation to prevent conflicts
  system.activationScripts.cleanup-hm-backups = {
    deps = [];
    text = ''
      echo "Cleaning up old home-manager backup files..."
      find /home/${username}/.config -name "*.hm-backup*" -type f -delete 2>/dev/null || true
      find /home/${username} -maxdepth 1 -name ".*.hm-backup*" -type f -delete 2>/dev/null || true
      if [ -L /home/${username}/.config/kscreenlockerrc ]; then
        rm -f /home/${username}/.config/kscreenlockerrc
      fi
    '';
  };
}
