{pkgs, ...}: {
  # Pinned to the 7.3.4 stable point release. The locked nixos-unstable still
  # ships 7.3.3, so this overrides only the kernel. Drop the override and use
  # pkgs.linuxPackages_latest once nixos-unstable packages 7.3.4 or newer.
  # 7.2.1 previously broke eDP mode detection on this machine: validate the
  # laptop panel after booting an update and retain a known-good generation.
  boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.linuxKernel.kernels.linux_7_3.override {
    argsOverride = rec {
      version = "7.3.4";
      modDirVersion = version;
      src = pkgs.fetchurl {
        url = "mirror://kernel/linux/kernel/v7.x/linux-${version}.tar.xz";
        hash = "sha256-sRtt+Clejpkf8EC3GqpJlKi1XKojtrCSkH8ZW1hA/R8=";
      };
    };
    # Ignore the firmware's ~10 s WMI event 0xE5 (reported as KEY_UNKNOWN).
    # Without this, fcitx5/Phono commits the pending pinyin when it fires.
    kernelPatches = [
      {
        name = "asus-nb-wmi-ignore-0xe5";
        patch = ../../patches/linux-asus-nb-wmi-ignore-0xe5.patch;
      }
    ];
  });
}
