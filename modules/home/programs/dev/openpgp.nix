{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  identity = import (../../../../users + "/${username}/openpgp.nix");
  signingReady = identity.signingKey != null && identity.publicKeyFile != null;
  gpg = lib.getExe config.programs.gpg.package;
in {
  assertions = [
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
      # Share smart-card access with ykman through pcscd rather than grabbing USB.
      scdaemonSettings = {
        disable-ccid = true;
        pcsc-shared = true;
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
        # Signing every working-copy rewrite would repeatedly require a touch.
        behavior = "drop";
      };
      git.sign-on-push = true;
    };
  };

  services.gpg-agent = {
    enable = true;
    enableScDaemon = true;
    # Leave the existing SSH agent alone; commit signing uses OpenPGP directly.
    enableSshSupport = false;
    pinentry.package = pkgs.pinentry-qt;
    noAllowExternalCache = true;
  };
}
