{lib, ...}: {
  # Enroll/test the IR camera before enabling the new generation:
  #   sudo linux-enable-ir-emitter configure
  #   sudo howdy add
  #   sudo howdy test
  # Sudo and swaylock accept a successful face match without a password,
  # falling back to YubiKey touch, then the password, if recognition fails or
  # the camera is absent. YubiKey ordering is in yubikey.nix.
  # Initial password login is unaffected. See docs/authentication.md.
  services.howdy = {
    enable = true;
    control = "required";
    settings.video.device_path = "/dev/video2";
  };

  # Howdy normally applies to every PAM service. Opt in only for sudo and
  # swaylock; SSH, login, su and polkit remain password/key based.
  security.pam = {
    howdy.enable = false;
    services = {
      sudo.howdy = {
        enable = true;
        control = "sufficient";
      };
      swaylock = {
        # Empty input can trigger Howdy, but must never authenticate via unix.
        allowNullPassword = lib.mkForce false;
        howdy = {
          enable = true;
          # NixOS orders Howdy before pam_unix: either sufficient rule can
          # finish authentication; failed recognition does not veto a password.
          control = "sufficient";
        };
      };
    };
  };

  # With Howdy disabled for polkit, its helper needs no camera access and the
  # upstream PrivateDevices sandbox can remain intact.
}
