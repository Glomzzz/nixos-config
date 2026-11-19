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
    ./gpu
    ./disk.nix
    ../common/snapshots.nix
    ../common/storage-health.nix
    ./power.nix
    ../common/bluetooth.nix
    ../common/audio.nix
    ./boot.nix
    ./asus.nix
    ../common/graphics-stack.nix
    ../common/input.nix
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  hardware.enableAllFirmware = true;
  hardware.enableRedistributableFirmware = true;
  environment.systemPackages = with pkgs; [
    thunderbolt
  ];
}
