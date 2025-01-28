{ modulesPath, ... }:

{
  nixpkgs.hostPlatform = "x86_64-linux";

  imports = [
    # Graphics crash. Disable for now.
    #  <nixos-hardware/asus/zephyrus/gu605my>
    ./cpu
    ./gpu
    ./disk.nix
    ./bluetooth.nix
    ./audio.nix
    ./boot.nix
    ./asus.nix
    ./graphic.nix
    (modulesPath + "/installer/scan/not-detected.nix")
    ];
 

  hardware.enableAllFirmware = true;
  hardware.enableRedistributableFirmware = true;

}
