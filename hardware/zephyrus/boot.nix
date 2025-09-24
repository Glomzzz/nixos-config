{ lib, ...} :{

  boot = {
    loader.systemd-boot.configurationLimit = 3;
    initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "nvme" "usb_storage" "usbhid" "sd_mod" "rtsx_pci_sdmmc" ];
    initrd.kernelModules = [ ];
    kernelModules = [ "kvm-intel"];
    kernelParams = [ "i915.enable_psr=0" "i8042.dumbkbd" ];
    loader = {
        grub = {
            enable = true;
            device = "nodev";
            efiSupport = true;
            useOSProber = false;
            gfxmodeEfi = "1920x1080";
            gfxmodeBios = "1920x1080";
            extraEntries = ''
                menuentry "Windows" {
                    search --file --no-floppy --set=root /EFI/Microsoft/Boot/bootmgfw.efi
                    chainloader (''${root})/EFI/Microsoft/Boot/bootmgfw.efi
                }
            '';
        };
        efi = {
            canTouchEfiVariables = true;
            efiSysMountPoint = "/boot";
        };
    };
  };
}
