{
  lib,
  username,
  ...
}: {
  nix.settings.trusted-users = lib.mkForce [
    "root"
    username
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
