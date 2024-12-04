{ ... }:

{

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/f14ed014-2ad0-4255-ba95-0ff742103f80";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/92E3-6297";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/cca23fdf-2621-4793-bc5a-7c1ef9041e73"; }
    ];
}
