{...} : {
  imports = [
    ./locale.nix
    ./display.nix
    ./audio.nix
    ./network.nix
    ./font.nix
    ./boot.nix
  ];


  services.printing.enable = true;

  services.asusd = {
      enable = true;
      enableUserService = true;
};
}