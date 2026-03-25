{ lib, ... }:
{
  nix.settings.trusted-users = lib.mkForce [
    "root"
    "glom"
  ];
  imports = [
    ./sops
    ./locale.nix
    ./fonts.nix
    ./networking.nix
    ./plasma-auth.nix
    ./nix-ld.nix
    ./home-manager.nix
  ];
}
