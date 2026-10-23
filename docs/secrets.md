# Secret management

## Human access: OpenPGP

The operator recipient in `.sops.yaml` is the primary fingerprint from
`users/glom/openpgp.nix`. Its encryption subkey is on the YubiKey, with touch
required. The public certificate is imported by Home Manager. PINs, private
keys, recovery material, and the old operator age identity stay outside this
repository and the Nix store.

Use SOPS as the normal user, not root:

```sh
sops secrets/users/glom.yaml
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

## On-demand user credentials

`secrets/users/glom.yaml` has **only** the operator OpenPGP recipient: no age,
cloud KMS, or unattended host recipient. GitHub, Skillw, SMB, and the preserved
but currently unused OpenCode credentials live here. They are not provisioned
into `/run/secrets` during boot or activation.

The installed helper never prints credentials. It decrypts the requested object
through SOPS and scopes its output to the selected child process or private
runtime file. It never invokes a shell to interpolate a secret:

```sh
user-credentials github -- gh api user
user-credentials github -- YOUR_COMMAND ARGUMENTS
user-credentials skillw -- YOUR_AI_COMMAND ARGUMENTS
mac-mini-connect
mac-mini-disconnect
```

- `github`: sets `GH_TOKEN`, `GITHUB_TOKEN`, and the legacy `GITHUB_PAT_TOKEN`
  only for the child and its descendants, not every Fish shell.
- `skillw`: sets `SKILLW_API_KEY_FILE` only for the child. The mode-0600 file
  lives in a mode-0700 temporary directory under `$XDG_RUNTIME_DIR` and is
  removed after command exit, including launch failure and normal termination.
  A daemon that outlives the command cannot rely on that file remaining available.
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
GitHub token or the old `SKILLW_API_KEY_FILE`; logout is needed to discard those
inherited values. Stop/reconnect any old SMB service using the new commands.
Mail remains unchanged: GNOME Keyring supports automatic synchronization without
requiring the YubiKey every five minutes.

**Rotate the provider-side GitHub, AI/OpenCode, and SMB credentials after this
migration.** Earlier repository history, Nix-store generations, snapshots, and
old host-decrypted runtime files can retain copies encrypted to the host or old
operator age key. Moving the same value to a new OpenPGP-only file does not
invalidate those copies. Secure deletion is not guaranteed on Btrfs/SSDs;
rotation is the effective way to revoke them. Old generations can restore the
old provisioning behavior; use only updated secrets/rotated credentials there.

These helpers do not isolate processes sharing your UID. An unlocked child can
use/disclose its credential; root can compromise it. Runtime storage is
nonpersistent, not a guarantee against swapping. SIGKILL/crashes can leave the
Skillw temporary file until runtime-directory cleanup. Full-disk and swap
encryption remain necessary for offline protection.

Regression tests use fake credentials, never real decryption or network access:

```sh
nix build --no-link .#checks.x86_64-linux.credentials .#checks.x86_64-linux.sops
```

## Unattended machine access

`modules/nixos/security/sops/default.nix` retains age decryption using
`/etc/ssh/ssh_host_ed25519_key`. Host secrets have both this recipient and the
operator's OpenPGP recipient in the **same key group**: either can decrypt.
Adding OpenPGP does not force a hardware check for host access. Only the
`tailscale/ip` entry remains in the host file; user credentials are deliberately
excluded from this unattended path.

The former software operator age recipient is removed from the current file.
Keep recovery material offline until OpenPGP access and backups have been
verified. Removing a recipient does not revoke access to older encrypted files
in repository history; rotate affected credentials if that old key was exposed.
Do not erase working recovery keys as part of ordinary configuration activation.

Boot/activation must not depend on the removable YubiKey. Machine secrets should
remain narrowly scoped, and full-disk encryption is needed to protect the host
SSH identity against offline disk access.
