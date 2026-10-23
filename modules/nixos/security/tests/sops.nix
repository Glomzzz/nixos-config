{
  config,
  pkgs,
}: let
  identity = import ../../../../users/glom/openpgp.nix;
  python = pkgs.python3.withPackages (ps: [ps.pyyaml]);
in
  assert config.sops.age.sshKeyPaths == ["/etc/ssh/ssh_host_ed25519_key"];
    pkgs.runCommand "sops-recipients-check" {
      nativeBuildInputs = [python];
    } ''
      python3 - ${../../../../.sops.yaml} ${../../../../secrets/hosts/nixos.yaml} ${identity.primaryFingerprint} <<'PY'
      import sys
      import yaml

      policy_path, secret_path, operator = sys.argv[1:]
      with open(policy_path) as source:
          policy = yaml.safe_load(source)
      with open(secret_path) as source:
          metadata = yaml.safe_load(source)["sops"]
      group, = policy["creation_rules"][0]["key_groups"]
      assert group["pgp"] == [operator], "Operator must use the OpenPGP identity"
      assert len(group["age"]) == 1, "Only the host age recipient should remain"
      assert [entry["fp"] for entry in metadata["pgp"]] == [operator]
      assert [entry["recipient"] for entry in metadata["age"]] == group["age"]
      print("OpenPGP operator and unattended host recipients match policy")
      PY
      touch "$out"
    ''
