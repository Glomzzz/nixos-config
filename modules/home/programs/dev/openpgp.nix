{
  config,
  lib,
  pkgs,
  hostname,
  username,
  ...
}: let
  identity = import (../../../../users + "/${username}/openpgp.nix");
  signingReady = identity.signingKey != null && identity.publicKeyFile != null;
  pinentry = import ./yubikey-pin/package.nix {
    inherit pkgs;
    inherit (identity) cardSerial;
  };
  saveYubikeyPin = import ./yubikey-pin/provision.nix {
    inherit pkgs hostname username;
  };
  gpg = lib.getExe config.programs.gpg.package;
in {
  home.packages = [saveYubikeyPin];

  assertions = [
    {
      assertion = builtins.match "[0-9]{1,8}" identity.cardSerial != null;
      message = "OpenPGP cardSerial must be the public decimal YubiKey serial for automatic user-PIN entry.";
    }
    {
      assertion =
        identity.signingKey
        == null
        || builtins.match "([0-9A-Fa-f]{40}|[0-9A-Fa-f]{64})!" identity.signingKey != null;
      message = "OpenPGP signingKey must be a full signing-subkey fingerprint followed by !.";
    }
    {
      assertion = (identity.signingKey == null) == (identity.publicKeyFile == null);
      message = "Configure both OpenPGP signingKey and publicKeyFile, or leave both null until provisioned.";
    }
  ];

  programs = {
    gpg = {
      enable = true;
      settings = lib.mkIf signingReady {
        default-key = identity.signingKey;
      };
      # Use pcscd rather than grabbing USB, but retain exclusive card access.
      # Shared access can lose PIN verification between operations (GnuPG T7041).
      # Release scdaemon before OpenPGP management with ykman; see docs/yubikey.md.
      scdaemonSettings = {
        disable-ccid = true;
      };
      publicKeys = lib.optional signingReady {
        source = identity.publicKeyFile;
        trust = "ultimate";
      };
    };

    # Do not enable broken signing or select an unrelated software key by email
    # before the public certificate and exact card signing subkey are configured.
    git.signing = lib.mkIf signingReady {
      format = "openpgp";
      key = identity.signingKey;
      signer = gpg;
      signByDefault = true;
    };
    jujutsu.settings = lib.mkIf signingReady {
      signing = {
        backend = "gpg";
        key = identity.signingKey;
        backends.gpg.program = gpg;
        # Create and rewrite unsigned; sign at push so the card touch is batched.
        behavior = "drop";
      };
      # Sign unsigned outgoing mutable commits authored by us, at push time.
      git.sign-on-push = true;
    };
  };

  services.gpg-agent = {
    enable = true;
    enableScDaemon = true;
    # Home Manager exports the socket to shells, systemd and D-Bus. The card's
    # authentication key is exposed automatically after card discovery.
    enableSshSupport = true;
    # Explicit opt-in saved-PIN provider; all unrelated prompts fall back to Qt.
    pinentry.package = pinentry;
    # Keep generic desktop/password-manager caching off. The saved card PIN is
    # a deliberate exception, supplied only by our serial-scoped helper.
    noAllowExternalCache = true;
  };
}
