{
  lib,
  username,
  ...
}: {
  nix.settings.trusted-users = lib.mkForce [
    "root"
    username
  ];

  # Follow the current system instead of keeping a copied Bash binary whose
  # store-backed loader and libraries can be removed by garbage collection.
  systemd.tmpfiles.rules = [
    "L+ /bin/bash - - - - /run/current-system/sw/bin/bash"
  ];

  imports = [
    ./fonts.nix
    ./home-manager.nix
    ./input.nix
    ./locale.nix
    ./networking.nix
    ./nix.nix
  ];
}
