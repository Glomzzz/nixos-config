{
  config,
  hostname,
  lib,
  pkgs,
  username,
  ...
}: {
  # Includes pcscd and the Yubico USB permissions needed by ykman/OpenPGP.
  programs.yubikey-manager.enable = true;
  environment.systemPackages = [pkgs.pam_u2f];

  # Background gpg-agent/scdaemon processes may have no active login session.
  # Allow only this account to use PC/SC; card PIN/touch checks still apply.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (
        subject.user === ${builtins.toJSON username}
        && (
          action.id === "org.debian.pcsc-lite.access_pcsc"
          || action.id === "org.debian.pcsc-lite.access_card"
        )
      ) {
        return polkit.Result.YES;
      }
    });
  '';

  # Enrollment data is public, but must not be user-writable at runtime.
  # The initially empty mapping simply falls through to face/password auth.
  environment.etc."u2f-mappings" = {
    source = ../../../users + "/${username}/u2f_keys";
    mode = "0444";
  };

  # pam-u2f opens/closes these empty markers during authentication. The user
  # notifier watches the events to name sudo/swaylock without inspecting root
  # processes. Markers are advisory only and never affect authentication.
  systemd.tmpfiles.rules =
    [
      "d /run/yubikey-touch 0755 root root -"
      "d /run/yubikey-touch/${username} 0755 root root -"
    ]
    ++ map (service: "f /run/yubikey-touch/${username}/${service} 0444 root root -") ["sudo" "swaylock"];

  security.pam = {
    u2f = {
      # Opt in below, never add a key dependency to login/SSH/recovery shells.
      enable = false;
      settings = {
        authfile = "/etc/u2f-mappings";
        origin = "pam://${hostname}";
        appid = "pam://${hostname}";
        cue = true;
        # This is touch-only convenience auth, not password + key or key + PIN.
        userpresence = 1;
        pinverification = 0;
        userverification = 0;
      };
    };
    services = lib.genAttrs ["sudo" "swaylock"] (service: {
      u2f = {
        enable = true;
        control = "sufficient";
      };
      rules.auth.u2f.settings.authpending_file = "/run/yubikey-touch/${username}/${service}";
      # NixOS normally orders U2F before Howdy. Preserve face-first behavior,
      # then try touch, then pam_unix. These methods are sequential, not parallel.
      rules.auth.u2f.order = config.security.pam.services.${service}.rules.auth.howdy.order + 10;
    });
  };
}
