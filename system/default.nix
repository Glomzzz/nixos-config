{lib, ...}: {
  imports = [
    ./locale.nix
    ./font.nix
    ./network.nix
    ./programs.nix
    ./env
    ./wine.nix
    ./nix-ld.nix
    ./steam.nix
  ];
  services.speechd.enable = (lib.mkForce false);
}
