{
  config,
  pkgs,
}: let
  home = config.home-manager.users.glom;
  credentials = import ./package.nix {
    inherit pkgs;
    secretsFile = ../../../../../secrets/users/glom.yaml;
  };
  smb = home.systemd.user.services.mac-mini-smb.Service;
in
  assert builtins.attrNames config.sops.secrets
  == ["tailscale/ip"]
  ++ pkgs.lib.optional (config.sops.secrets ? "yubikey/openpgp-user-pin") "yubikey/openpgp-user-pin";
  assert !(config.sops.templates ? "smb-mac-mini-credentials");
  assert !(home.home.sessionVariables ? SKILLW_API_KEY_FILE);
  assert !(pkgs.lib.hasInfix "GITHUB_PAT_TOKEN" home.programs.fish.shellInit);
  assert smb.LoadCredential == ["smb.json:%t/nixos-credentials/mac-mini-smb.json"];
  assert smb.UMask == "0077";
    pkgs.runCommand "user-credentials-check" {
      nativeBuildInputs = [pkgs.python3 credentials];
      mount = smb.ExecStart;
      # Realize the shellchecked connect/disconnect packages without mounting.
      helpers = builtins.filter (package:
        builtins.elem (pkgs.lib.getName package) ["mac-mini-connect" "mac-mini-disconnect"])
      home.home.packages;
    } ''
      export PYTHONDONTWRITEBYTECODE=1
      python3 ${./tests.py} ${./credentials.py}
      user-credentials --help >/dev/null
      python3 - "$mount" <<'PY'
      import pathlib
      import sys

      script = pathlib.Path(sys.argv[1]).read_text()
      assert "CREDENTIALS_DIRECTORY" in script
      assert "rclone obscure" not in script
      assert "smb-credentials" not in script
      assert "/run/secrets" not in script
      print("SMB consumes runtime systemd credentials without persistent password caching")
      PY
      touch "$out"
    ''
