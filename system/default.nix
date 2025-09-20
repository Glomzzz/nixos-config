{pkgs,...}@all : {
  imports = [
    ./locale.nix
    ./font.nix
    ./network.nix
    ./programs.nix
    ./env
  ];
}
