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
  # KDE Wallet auto-unlock:
  #   - Wallet name must be "kdewallet" with Blowfish encryption
  #   - Wallet password must match your login password
  #   - Password-based logins can pass the password to kwallet-pam
  #   - SDDM auto-login supplies no password, so an encrypted wallet prompts
  #     once after login instead of weakening its encryption
  #
  #############################################################################

  services.howdy = {
    enable = true;

    # "sufficient": face alone is enough (skip password if face matches).
    # "required": 2FA mode (face + password both needed).
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

  # Keep password-based login services from bypassing the password that
  # kwallet-pam needs. SDDM auto-login uses a separate PAM service.
  security.pam.services.login.howdy.enable = false;

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
