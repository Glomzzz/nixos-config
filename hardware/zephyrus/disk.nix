{ ... }:

{

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/5094e655-4d5d-48df-90db-45e62e42d1e1";
      fsType = "btrfs";
      options = [ "subvol=@" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/C3AB-ABB0";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/d7e33875-391a-4d29-9abe-4f990ef53fce"; }
    ];
}
