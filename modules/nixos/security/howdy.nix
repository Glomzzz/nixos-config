_: {
  # Enroll/test the IR camera before enabling the new generation:
  #   sudo linux-enable-ir-emitter configure
  #   sudo howdy add
  #   sudo howdy test
  # Sudo accepts a successful face match without a password, falling back to
  # the password if recognition fails. Swaylock still requires both factors.
  # Password login is unaffected. See docs/authentication.md.
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
      swaylock.howdy.enable = true;
    };
  };

  # With Howdy disabled for polkit, its helper needs no camera access and the
  # upstream PrivateDevices sandbox can remain intact.
}
