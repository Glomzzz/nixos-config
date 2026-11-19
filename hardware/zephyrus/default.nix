{
  modulesPath,
  pkgs,
  ...
}: {
  nixpkgs.hostPlatform = "x86_64-linux";

  imports = [
    # Graphics crash. Disable for now.
    #  <nixos-hardware/asus/zephyrus/gu605my>
    ../common/cpu
    ../common/snapshots.nix
    ../common/storage-health.nix
    ../common/bluetooth.nix
    ../common/audio.nix
    ../common/graphics-stack.nix
    ../common/input.nix
    ./gpu
    ./disk.nix
    ./power.nix
    ./boot.nix
    ./asus.nix
    ./kernel.nix
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  hardware.enableAllFirmware = true;
  hardware.enableRedistributableFirmware = true;
  environment.systemPackages = with pkgs; [
    thunderbolt
  ];
}
