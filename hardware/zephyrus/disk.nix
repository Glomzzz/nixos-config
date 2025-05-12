{ ... }:

{

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/d2e23fd9-5500-40e5-a41a-dea6c37cbf96";
      fsType = "btrfs";
      options = [ "subvol=@" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/CEBC-DA24";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/19460597-1975-48a9-a2be-0f4fb6207883"; }
    ];

}
