{...}: {
  imports = [
    ./nix.nix
    ./locale.nix
    ./fonts.nix
    ./networking.nix
    ./plasma-auth.nix
    ./sops.nix
    (./. + "/home-manager.nix")
  ];
}
