{
  config,
  pkgs,
}: let
  home = config.home-manager.users.glom;
  identity = import ../../../../../users/glom/openpgp.nix;
  ready = identity.signingKey != null && identity.publicKeyFile != null;
  git = home.programs.git;
  jj = home.programs.jujutsu.settings;
  gpg = home.programs.gpg;
  agent = home.services.gpg-agent;
in
  assert config.programs.yubikey-manager.enable;
  assert config.services.pcscd.enable;
  assert gpg.enable && agent.enable && agent.enableScDaemon;
  assert gpg.scdaemonSettings.disable-ccid && gpg.scdaemonSettings.pcsc-shared;
  assert !agent.enableSshSupport;
  assert agent.pinentry.package == pkgs.pinentry-qt;
  assert agent.noAllowExternalCache;
  assert gpg.mutableKeys && gpg.mutableTrust;
  assert if ready
  then
    git.signing.format
    == "openpgp"
    && git.signing.key == identity.signingKey
    && git.signing.signByDefault
    && git.signing.signer == pkgs.lib.getExe gpg.package
    && jj.signing.backend == "gpg"
    && jj.signing.key == identity.signingKey
    && jj.signing.backends.gpg.program == pkgs.lib.getExe gpg.package
    && jj.signing.behavior == "drop"
    && jj.git.sign-on-push
    && builtins.length gpg.publicKeys == 1
  else
    git.signing.signByDefault
    != true
    && !(jj ? signing)
    && !(jj.git.sign-on-push or false)
    && gpg.publicKeys == [];
    pkgs.runCommand "openpgp-check" {
      nativeBuildInputs = [pkgs.gnupg pkgs.python3];
      signingKey =
        if ready
        then identity.signingKey
        else "";
    } ''
      ${pkgs.lib.optionalString ready ''
        export GNUPGHOME
        GNUPGHOME=$(mktemp -d)
        gpg --batch --no-options --with-colons --show-keys ${pkgs.lib.escapeShellArg (toString identity.publicKeyFile)} > public-keys.txt
        python3 - "$signingKey" public-keys.txt <<'PY'
        import pathlib
        import sys

        expected = sys.argv[1].removesuffix("!").upper()
        signing_subkey = False
        found = False
        for line in pathlib.Path(sys.argv[2]).read_text().splitlines():
            fields = line.split(":")
            if fields[0] in ("pub", "sub"):
                signing_subkey = fields[0] == "sub" and "s" in fields[11].lower()
            elif fields[0] == "fpr" and signing_subkey and fields[9].upper() == expected:
                found = True
        assert found, "Configured fingerprint is not a signing subkey in the public certificate"
        PY
      ''}
      touch "$out"
    ''
