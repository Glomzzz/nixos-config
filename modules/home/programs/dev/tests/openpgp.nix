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
  assert gpg.scdaemonSettings.disable-ccid;
  assert !(gpg.scdaemonSettings ? pcsc-shared);
  assert agent.enableSshSupport;
  assert !config.programs.ssh.startAgent && !home.services.ssh-agent.enable;
  assert home.sshAuthSock.enable;
  assert home.sshAuthSock.systemd.socketProviderUnit == "gpg-agent-ssh.socket";
  assert home.programs.ssh.settings."*".data.IdentityFile == "~/.ssh/yubikey-openpgp.pub";
  assert home.programs.ssh.settings."*".data.IdentitiesOnly;
  assert home.programs.ssh.settings."*".data.ForwardAgent == false;
  assert home.home.file.".ssh/yubikey-openpgp.pub".source == identity.sshPublicKeyFile;
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
    && jj.signing.behavior == "own"
    && jj.git.sign-on-push
    && gpg.settings.default-key == identity.signingKey
    && builtins.length gpg.publicKeys == 1
  else
    git.signing.signByDefault
    != true
    && !(jj ? signing)
    && !(jj.git.sign-on-push or false)
    && !(gpg.settings ? default-key)
    && gpg.publicKeys == [];
    pkgs.runCommand "openpgp-check" {
      nativeBuildInputs = [pkgs.gnupg pkgs.openssh pkgs.python3];
      signingKey =
        if ready
        then identity.signingKey
        else "";
    } ''
      ssh -G -F ${home.home.file.".ssh/config".source} github.com > ssh-settings.txt
      python3 - <<'PY'
      import pathlib

      settings = [line.split(maxsplit=1) for line in pathlib.Path("ssh-settings.txt").read_text().splitlines()]
      assert [value for key, value in settings if key == "identityfile"] == ["~/.ssh/yubikey-openpgp.pub"]
      assert [value for key, value in settings if key == "identitiesonly"] == ["yes"]
      assert [value for key, value in settings if key == "forwardagent"] == ["no"]
      PY
      ${pkgs.lib.optionalString ready ''
        export GNUPGHOME
        GNUPGHOME=$(mktemp -d)
        gpg --batch --no-options --import ${pkgs.lib.escapeShellArg "${identity.publicKeyFile}"}
        gpg --batch --no-options --with-colons --list-keys > public-keys.txt
        gpg --batch --no-options --export-ssh-key '${identity.authenticationKey}!' > ssh-key.pub
        python3 - ${identity.sshPublicKeyFile} <<'PY'
        import pathlib
        import sys

        expected = pathlib.Path(sys.argv[1]).read_text().split()[:2]
        actual = pathlib.Path("ssh-key.pub").read_text().split()[:2]
        assert actual == expected, "SSH public key must match the exact authentication subkey"
        PY
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
