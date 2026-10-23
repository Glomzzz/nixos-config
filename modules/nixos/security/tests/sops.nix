{
  config,
  pkgs,
}: let
  identity = import ../../../../users/glom/openpgp.nix;
  python = pkgs.python3.withPackages (ps: [ps.pyyaml]);
  pinFile = ../../../../secrets/hosts/nixos-yubikey-pin.yaml;
  pinPath =
    if builtins.pathExists pinFile
    then "${pinFile}"
    else "";
in
  assert config.sops.age.sshKeyPaths == ["/etc/ssh/ssh_host_ed25519_key"];
    pkgs.runCommand "sops-recipients-check" {
      nativeBuildInputs = [python];
    } ''
      python3 - ${../../../../.sops.yaml} ${../../../../secrets/hosts/nixos.yaml} ${../../../../secrets/users/glom.yaml} ${identity.primaryFingerprint} '${pinPath}' <<'PY'
      import re
      import sys
      import yaml

      policy_path, host_path, user_path, operator, pin_path = sys.argv[1:]
      with open(policy_path) as source:
          policy = yaml.safe_load(source)
      with open(host_path) as source:
          host = yaml.safe_load(source)
      with open(user_path) as source:
          user = yaml.safe_load(source)
      host_rule, = [rule for rule in policy["creation_rules"] if re.fullmatch(rule["path_regex"], "secrets/hosts/nixos.yaml")]
      group, = host_rule["key_groups"]
      assert group["pgp"] == [operator], "Operator must use the OpenPGP identity"
      assert len(group["age"]) == 1, "Only the host age recipient should remain"
      assert [entry["fp"] for entry in host["sops"]["pgp"]] == [operator]
      assert [entry["recipient"] for entry in host["sops"]["age"]] == group["age"]
      assert set(host) == {"tailscale", "sops"}, "User credentials must not remain in host secrets"
      pin_rule, = [rule for rule in policy["creation_rules"] if re.fullmatch(rule["path_regex"], "secrets/hosts/nixos-yubikey-pin.yaml")]
      assert pin_rule["key_groups"] == [{"age": group["age"]}], "Saved PIN must use only the host recipient, not the card it unlocks"
      pin = None
      if pin_path:
          with open(pin_path) as source:
              pin = yaml.safe_load(source)
          assert set(pin) == {"openpgp_user_pin", "sops"}
          assert [entry["recipient"] for entry in pin["sops"]["age"]] == group["age"]
          for alternate in ("pgp", "kms", "gcp_kms", "azure_kv", "hc_vault", "key_groups"):
              assert not pin["sops"].get(alternate), "Saved PIN must not depend on alternate recipients"
      user_rule, = [rule for rule in policy["creation_rules"] if re.fullmatch(rule["path_regex"], "secrets/users/glom.yaml")]
      assert user_rule["key_groups"] == [{"pgp": [operator]}]
      assert [entry["fp"] for entry in user["sops"]["pgp"]] == [operator]
      for fallback in ("age", "kms", "gcp_kms", "azure_kv", "hc_vault", "key_groups"):
          assert not user["sops"].get(fallback), "User secrets must have no alternate decryption recipient"
      assert set(user) == {"github", "skillw", "smb", "opencode", "sops"}
      assert set(user["smb"]["mac-mini"]) == {"username", "obscured_password"}

      def encrypted_leaves(value):
          if isinstance(value, dict):
              for child in value.values():
                  encrypted_leaves(child)
          else:
              assert isinstance(value, str) and value.startswith("ENC[AES256_GCM,"), "Unexpected plaintext secret leaf"

      for document in (host, user, *([pin] if pin is not None else [])):
          encrypted_leaves({key: value for key, value in document.items() if key != "sops"})
      print("OpenPGP-only user secrets, separate host-only saved PIN, and ciphertext-only values match policy")
      PY
      touch "$out"
    ''
