{...} : {
  imports = [
    ./locale.nix
    ./display.nix
    ./audio.nix
    ./network.nix
    ./font.nix
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  services.printing.enable = true;
}