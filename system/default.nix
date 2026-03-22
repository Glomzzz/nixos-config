{pkgs,lib ,...}@all : {
  imports = [
    ./locale.nix
    ./font.nix
    ./network.nix
    ./programs.nix
    ./ollama.nix
    ./sub2api.nix
    ./env
    ./wine.nix
    ./nix-ld.nix
    ./steam.nix
    ./clamav.nix
  ];
  services.speechd.enable = (lib.mkForce false);
}
