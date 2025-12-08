{pkgs,lib ,...}@all : {
  imports = [
    ./locale.nix
    ./font.nix
    ./network.nix
    ./programs.nix
    ./env
  ];
  services.speechd.enable = (lib.mkForce false);
}
