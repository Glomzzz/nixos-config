_: {
  # Enroll/test the IR camera before enabling the new generation:
  #   sudo linux-enable-ir-emitter configure
  #   sudo howdy add
  #   sudo howdy test
  # Password login stays available if the camera fails. Only sudo and swaylock
  # require face recognition as an additional factor, never as a replacement
  # for the account password. See docs/authentication.md.
  services.howdy = {
    enable = true;
    control = "required";
    settings.video.device_path = "/dev/video2";
  };

  # Howdy normally applies to every PAM service. Opt in only where both
  # factors are intended; SSH, login, su and polkit remain password/key based.
  security.pam = {
    howdy.enable = false;
    services = {
      sudo.howdy.enable = true;
      swaylock.howdy.enable = true;
    };
  };

  # With Howdy disabled for polkit, its helper needs no camera access and the
  # upstream PrivateDevices sandbox can remain intact.
}
