{
  pkgs,
  username,
  ...
}: {
  # Physical Android devices expose their files over MTP rather than as block
  # devices. FUSE lets the Home Manager helper mount that storage as a normal
  # directory, and libmtp's udev rules grant the active session USB access.
  programs.fuse.enable = true;
  services.udev.packages = [pkgs.libmtp.out];

  environment.sessionVariables = {
    # Android Studio already sets this in its wrapper. Export it globally as
    # well so emulator binaries launched directly from the SDK use host libs.
    ANDROID_EMULATOR_USE_SYSTEM_LIBS = "1";
  };

  environment.systemPackages = with pkgs; [
    android-tools
    android-studio
    mesa-demos
    pciutils
    vulkan-tools
    setxkbmap
  ];

  users.users.${username}.extraGroups = [
    "kvm"
  ];
}
