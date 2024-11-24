{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    #  <nixos-hardware/asus/zephyrus/gu605my>
    ./cpu
    ./gpu
   (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "usbhid" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  # boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "kvm-intel"];
  # boot.extraModulePackages = with config.boot.kernelPackages; [ rtl8812au ];
  # boot.blacklistedKernelModules = lib.mkDefault [ "i915" ];
  # KMS will load the module, regardless of blacklisting
  boot.kernelParams = lib.mkDefault [ "i915.modeset=0" ];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
      };
    };
  };
  
  hardware.enableAllFirmware = true;
  hardware.enableRedistributableFirmware = true;
  fileSystems."/" =
    { device = "/dev/disk/by-uuid/98cd699b-86f0-4521-a4e9-10f18a0cf917";
      fsType = "btrfs";
      options = [ "subvol=@" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/1CA5-E29C";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/1a9c5484-6c14-4b75-acaa-c7228a5fd645"; }
    ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp0s13f0u1u1u1.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp46s0f0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}