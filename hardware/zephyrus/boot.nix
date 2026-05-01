{...}: {
  boot = {
    loader.systemd-boot.enable = false;
    loader.grub = {
      enable = true;
      configurationLimit = 3;
      device = "nodev";
      efiSupport = true;
      useOSProber = false;
      gfxmodeEfi = "1920x1080";
      gfxmodeBios = "1920x1080";
      gfxpayloadEfi = "text";
      extraEntries = ''
        menuentry "Windows" {
          search --file --no-floppy --set=root /EFI/Microsoft/Boot/bootmgfw.efi
          chainloader (''${root})/EFI/Microsoft/Boot/bootmgfw.efi
        }
      '';
    };
    initrd.availableKernelModules = [
      "xhci_pci"
      "thunderbolt"
      "nvme"
      "usb_storage"
      "usbhid"
      "sd_mod"
      "rtsx_pci_sdmmc"
    ];
    initrd.kernelModules = [];
    kernelModules = ["kvm-intel"];
    kernelParams = [
      "i915.enable_psr=0"
      "i8042.dumbkbd"
    ];
    loader.efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };
}
