{lib, ...}: {
  nix.settings.trusted-users = lib.mkForce [
    "root"
    "glom"
  ];
  imports = [
    ./locale.nix
    ./fonts.nix
    ./networking.nix
    ./plasma-auth.nix
    ./sops.nix
    (./. + "/home-manager.nix")
  ];
}
