{pkgs, ...}: {
  services.usbmuxd = {
    enable = true;
    package = pkgs.usbmuxd2;
  };

  # iloader is temporarily removed: nixpkgs' current build fails (aws-lc-sys
  # cannot find the openssl headers). Re-add it once nixpkgs fixes the build.
  environment.systemPackages = with pkgs; [
    libimobiledevice
    ifuse
  ];
}
