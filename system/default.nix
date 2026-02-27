{pkgs,lib ,...}@all : {
  imports = [
    ./locale.nix
    ./font.nix
    ./network.nix
    ./programs.nix
    ./env
    ./wine.nix
  ];
  services.speechd.enable = (lib.mkForce false);
}
