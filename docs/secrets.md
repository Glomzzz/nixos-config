# Secret management

## Human access: OpenPGP

The operator recipient in `~/nixos-secrets/.sops.yaml` is the primary fingerprint from
`users/glom/openpgp.nix`. Its encryption subkey is on the YubiKey, with touch
required. The public certificate is imported by Home Manager. Plaintext PINs,
private keys, recovery material, and the old operator age identity stay outside
this repository and the Nix store. The explicitly opted-in host-encrypted
OpenPGP user PIN described below is the only saved-PIN exception.

Use SOPS as the normal user, not root:

```sh
cd ~/nixos-secrets
sops secrets/users/glom.yaml
```

Decryption requires the card and its configured PIN/touch policy. Encryption
to the public certificate does not require the card. SOPS may invoke an editor
with plaintext; use a trusted editor with recovery/backup files disabled or
confined to a nonpersistent runtime directory. This machine's swap is currently
unencrypted, so tmpfs alone does not guarantee plaintext cannot reach disk.

Changing `~/nixos-secrets/.sops.yaml` only changes policy for future operations. To apply new
recipients to an existing file, use `sops updatekeys FILE` and inspect only the
encrypted diff. The regression check validates both policy and encrypted-file
metadata without decrypting anything:

```sh
./scripts/with-github-token nix build --no-link .#checks.x86_64-linux.sops
```

## Nix private-input credentials

The rebuild wrapper prefers `~/.config/nixos/github-read-token` (or
`$NIX_GITHUB_TOKEN_FILE`) over the general `gh` account. Provision a fine-grained
GitHub token limited to **Contents: read** for `Glomzzz/nixos-secrets` and store it
in that regular, user-owned file with mode `0600`. Use a hidden local prompt or
password manager; never put the value in argv, a Nix expression, shell history,
or this repository. A private file is still persistent plaintext: protect its
parent directory and encrypt the disk. This wrapper is scope reduction, not
protection from processes sharing your UID.

Build/evaluate with the new read-only credential before revoking or narrowing
the older token. Until the file exists, `gh auth token` remains a migration
fallback. The wrapper preserves unrelated `NIX_CONFIG` settings and never
writes a token into Nix configuration. At Home Manager activation, a targeted
migration removes `access-tokens` and `extra-access-tokens` assignments from
`~/.config/nix/nix.conf`, preserves other lines, and makes the result mode `0600`.
It refuses symlinks and creates no backup containing the old credential.
Included config files and custom `NIX_USER_CONF_FILES` paths require separate
manual review; the migration does not recursively follow configuration files.

No real credential is provisioned, rotated, or deleted merely by committing this
configuration. After validating the replacement, rotate/revoke the provider-side
broad token; removing a local setting does not revoke older copies in snapshots,
backups, or prior processes. Tests use fake tokens only:

```sh
./scripts/with-github-token nix build --no-link .#checks.x86_64-linux.nix-credentials
```

## On-demand user credentials

`secrets/users/glom.yaml` has **only** the operator OpenPGP recipient: no age,
cloud KMS, or unattended host recipient. GitHub and SMB credentials live here.
They are not provisioned
into `/run/secrets` during boot or activation.

The installed helper never prints credentials. It decrypts the requested object
through SOPS and scopes its output to the selected child process or private
runtime file. It never invokes a shell to interpolate a secret:

```sh
user-credentials github -- gh api user
user-credentials github -- YOUR_COMMAND ARGUMENTS
user-credentials ssh-host -- root@credential-host
mac-mini-connect
mac-mini-disconnect
```

- `github`: sets `GH_TOKEN`, `GITHUB_TOKEN`, and the legacy `GITHUB_PAT_TOKEN`
  only for the child and its descendants, not every Fish shell.
- `mac-mini-connect`: explicitly decrypts SMB credentials before starting an
  inactive service. Restarting the mount never triggers a background PIN prompt.
  The service uses systemd `LoadCredential` from a private runtime JSON file.
  Service restarts can reuse this unlocked connection until disconnected.
- `mac-mini-disconnect`: stops the mount and removes the staging credential;
  systemd removes its service credential copy when the service stops. A plain
  `systemctl --user stop` does not remove the staging file: use the disconnect
  command to lock it. All runtime copies also disappear with the user runtime
  directory at logout/shutdown (subject to lingering sessions).

The SMB `obscured_password` value is **password-equivalent**, not secure
cryptography. Its persistent copy now exists only inside OpenPGP encryption.
Keeping the obscured representation stable avoids changing rclone's VFS cache
identity on every restart. Migration reuses the former cached representation
when its fingerprint matches. Home Manager activation removes the old
`~/.cache/rclone/mac-mini/smb-credentials` file; it does not delete the VFS cache,
which can contain dirty writes and private file contents. Do not delete that
cache or rotate the SMB password until pending writes have been synchronized.

When changing the SMB password, update the encrypted `obscured_password` field,
not an unencrypted rclone config. For example, in Bash from this repository,
with Python, rclone, and SOPS on PATH (the value travels only through pipes):

```bash
python3 - <<'PY'
import getpass
import json
import subprocess

password = getpass.getpass("New SMB password: ")
if not password or any(c in password for c in "\r\n\x00"):
    raise SystemExit("A non-empty, single-line password is required")
obscured = subprocess.run(
    ["rclone", "obscure", "-"], input=password + "\n", text=True,
    stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
).stdout.rstrip("\n")
subprocess.run(
    ["sops", "set", "--value-stdin", "secrets/users/glom.yaml",
     '["smb"]["mac-mini"]["obscured_password"]'],
    input=json.dumps(obscured), text=True, check=True,
)
PY
```

Rebuild after editing: the helper consumes the encrypted file pinned in that
Home Manager generation. Do not run token-printing commands such as `env` under
the GitHub wrapper, put credentials into command arguments, or enable shell
tracing around credential operations.

### Activation and security boundaries

No deployed services or credentials are changed just by committing this config.
After building and testing the new generation, activate it and start a fresh
login session. Existing shells/processes may still hold the previously exported
GitHub token; logout is needed to discard that
inherited values. Stop/reconnect any old SMB service using the new commands.
Mail remains unchanged: GNOME Keyring supports automatic synchronization without
requiring the YubiKey every five minutes.

**Rotate the provider-side GitHub and SMB credentials after this migration.** Earlier repository history, Nix-store generations, snapshots, and
old host-decrypted runtime files can retain copies encrypted to the host or old
operator age key. Moving the same value to a new OpenPGP-only file does not
invalidate those copies. Secure deletion is not guaranteed on Btrfs/SSDs;
rotation is the effective way to revoke them. Old generations can restore the
old provisioning behavior; use only updated secrets/rotated credentials there.

These helpers do not isolate processes sharing your UID. An unlocked child can
use/disclose its credential; root can compromise it. Runtime storage is
nonpersistent, not a guarantee against swapping. SIGKILL/crashes can leave the
credential files until runtime-directory cleanup. Full-disk and swap
encryption remain necessary for offline protection.

Regression tests use fake credentials, never real decryption or network access:

```sh
./scripts/with-github-token nix build --no-link .#checks.x86_64-linux.credentials .#checks.x86_64-linux.sops
```

## Opt-in automatic OpenPGP user-PIN entry

`secrets/hosts/nixos-yubikey-pin.yaml` is a separate convenience secret with only
the host age recipient. It must not be added to the YubiKey-only user file:
that would require the PIN to decrypt itself. It does not add a host recipient
to any existing user credentials.

The local `sops-save-yubikey-pin` command takes hidden terminal input and writes
only ciphertext. sops-nix exposes the enrolled value as a mode-0400, user-owned
runtime secret; a serial-scoped pinentry provider supplies it over GPG's pipe,
with Qt fallback and conservative replay protection. Until the encrypted file
exists, no saved-PIN runtime secret is installed. Never print the runtime file,
put the PIN in Nix expressions, or pass it in command arguments/environment.

This **removes the PIN as an independent protection** from this laptop. The host
can decrypt it, the owning UID can read its runtime copy, and the current
unencrypted disk/swap exposes it to offline compromise. Card private keys and
required touches remain on the YubiKey, but other OpenPGP-protected user secrets
now rely on that hardware/touch rather than a manually entered PIN. Encrypting
the saved PIN in SOPS does not undo this trade-off. See
[YubiKey setup](yubikey.md#optional-host-decryptable-user-pin) for enrollment,
activation, testing, stale-PIN handling, and revoking historical saved values.

## Unattended machine access

`modules/nixos/security/sops/default.nix` retains age decryption using
`/etc/ssh/ssh_host_ed25519_key`. Host secrets have both this recipient and the
operator's OpenPGP recipient in the **same key group**: either can decrypt.
Adding OpenPGP does not force a hardware check for host access. Only the
`tailscale/ip` entry remains in the original host file; the optional saved user
PIN uses its own host-only file. Existing user credentials remain excluded from
the unattended decryption path, although saved PIN entry deliberately removes
the need to type their card PIN.

The former software operator age recipient is removed from the current file.
Keep recovery material offline until OpenPGP access and backups have been
verified. Removing a recipient does not revoke access to older encrypted files
in repository history; rotate affected credentials if that old key was exposed.
Do not erase working recovery keys as part of ordinary configuration activation.

Boot/activation must not depend on the removable YubiKey. Machine secrets should
remain narrowly scoped, and full-disk encryption is needed to protect the host
SSH identity against offline disk access.
