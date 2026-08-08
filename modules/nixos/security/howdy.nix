{lib, ...}: {
  #############################################################################
  #
  # Howdy - Windows Hello-style facial authentication for Linux
  #
  # Post-install setup:
  #   1. Find your camera:  ls /dev/video*  or  v4l2-ctl --list-devices
  #   2. Configure IR emitter (if available):
  #        sudo linux-enable-ir-emitter configure
  #   3. Enroll your face:
  #        sudo howdy add
  #   4. Test:
  #        sudo howdy test
  #        sudo -i
  #
  # Keyring unlock (previously KDE Wallet, now gnome-keyring):
  #   niri has no wallet of its own, so secrets live in gnome-keyring. There is
  #   no greeter any more (see desktop/autologin.nix): tty1 autologins, so no
  #   password reaches PAM and the login keyring must have an empty password.
  #   Nothing here needs to preserve a password prompt for the keyring's sake.
  #
  #############################################################################

  services.howdy = {
    enable = true;

    # "sufficient": face alone is enough (skip password if face matches).
    # "required": 2FA mode (face + password both needed).
    # Face auth is for sudo and swaylock; login itself is autologin.
    control = "sufficient";

    settings = {
      video = {
        # Run `ls /dev/video*` to find your IR/front camera device.
        # Common paths: /dev/video0, /dev/video2
        device_path = "/dev/video2";

        # Uncomment and tune if camera resolution is wrong:
        # frame_width = 640;
        # frame_height = 320;
      };
    };
  };

  # === polkit-127 Workaround ===
  # polkit >= 127 isolates helpers with PrivateDevices, which breaks howdy's
  # access to /dev/video*. This allows the polkit agent-helper to access the
  # video device for face auth.
  # See: https://github.com/NixOS/nixpkgs/issues/483867
  systemd.services."polkit-agent-helper@".serviceConfig = {
    DeviceAllow = "char-video4linux rw";
    PrivateDevices = lib.mkForce false;
  };
}
