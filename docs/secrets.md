# Secret management

## Human access: OpenPGP

The operator recipient in `.sops.yaml` is the primary fingerprint from
`users/glom/openpgp.nix`. Its encryption subkey is on the YubiKey, with touch
required. The public certificate is imported by Home Manager. PINs, private
keys, recovery material, and the old operator age identity stay outside this
repository and the Nix store.

Use SOPS as the normal user, not root:

```sh
sops secrets/hosts/nixos.yaml
```

Decryption requires the card and its configured PIN/touch policy. Encryption
to the public certificate does not require the card. SOPS may invoke an editor
with plaintext; use a trusted editor with recovery/backup files disabled or
confined to a nonpersistent runtime directory. This machine's swap is currently
unencrypted, so tmpfs alone does not guarantee plaintext cannot reach disk.

Changing `.sops.yaml` only changes policy for future operations. To apply new
recipients to an existing file, use `sops updatekeys FILE` and inspect only the
encrypted diff. The regression check validates both policy and encrypted-file
metadata without decrypting anything:

```sh
nix build --no-link .#checks.x86_64-linux.sops
```

## Unattended machine access

`modules/nixos/security/sops/default.nix` retains age decryption using
`/etc/ssh/ssh_host_ed25519_key`. Host secrets have both this recipient and the
operator's OpenPGP recipient in the **same key group**: either can decrypt.
Adding OpenPGP does not force a hardware check for host access.

The former software operator age recipient is removed from the current file.
Keep recovery material offline until OpenPGP access and backups have been
verified. Removing a recipient does not revoke access to older encrypted files
in repository history; rotate affected credentials if that old key was exposed.
Do not erase working recovery keys as part of ordinary configuration activation.

Boot/activation must not depend on the removable YubiKey. Machine secrets should
remain narrowly scoped, and full-disk encryption is needed to protect the host
SSH identity against offline disk access.
