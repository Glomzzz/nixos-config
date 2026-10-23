# YubiKey: local authentication and OpenPGP signing

The inspected device is a YubiKey 5C NFC, firmware 5.8.0. FIDO U2F/FIDO2
and OpenPGP are enabled. Its OpenPGP slots were empty at setup time; neither
public keys nor secret-key references existed in this machine's GnuPG keyring.
No key generation, reset, PIN change, or transfer is performed by Nix activation.

## What this configuration enables

- `programs.yubikey-manager`: `ykman`, PC/SC smart-card access, and Yubico USB rules.
- `pamu2fcfg` for FIDO enrollment. Runtime authentication uses a root-owned
  `/etc/u2f-mappings`, generated from `users/glom/u2f_keys` (initially empty).
- Only `sudo` and `swaylock` try **Howdy -> YubiKey touch -> account password**.
  These are sufficient alternatives, not mandatory two-factor authentication.
  PAM runs them sequentially: touch begins only after Howdy fails/times out.
  A connected, untouched key can delay password fallback; unplug it to skip it.
  Missing enrollment or hardware must fall through, never authenticate anyone.
- Initial graphical/TTY login, SSH, and `su` remain unchanged. A polkit rule
  allows only the configured user (`glom`) the two PC/SC access actions, including
  background GPG processes without an active session. Other polkit permissions
  remain unchanged; OpenPGP still requires its configured PIN/touch checks.
- Home Manager configures GnuPG, a socket-activated agent, Qt pinentry, and
  shared PC/SC access. GnuPG does not replace the SSH agent.
- Git/Jujutsu signing stays **disabled until provisioned**. Once both fields in
  `users/glom/openpgp.nix` are set, the public certificate is imported, and GnuPG,
  Git, and Jujutsu all select the same exact signing subkey. Git signs commits/tags
  by default, and Jujutsu signs commits authored by you when creating or rewriting
  them (`signing.behavior = "own"`), including working-copy snapshots. This may
  require a YubiKey touch on each rewrite. Sign-on-push remains enabled as a fallback
  for unsigned outgoing mutable commits authored by you.
  `jj sign -r REV` can sign an explicitly selected revision manually. Signing
  changes commit hashes; review the outgoing stack before pushing.

Public FIDO enrollment records and OpenPGP public certificates may live in this
repository/Nix store. **Never add private keys, secret-key exports, revocation
certificates, PINs, or passphrases.** Nix does not provision private keys.

## 1. Build and activate the tooling safely

From this repository, save your work and keep a root recovery shell open on
another VT (`sudo -i`). Verify that you know the account password first.

```sh
nix build --no-link .#checks.x86_64-linux.authentication .#checks.x86_64-linux.openpgp
sudo nixos-rebuild build --flake .#nixos
sudo nixos-rebuild test --flake .#nixos
```

Test a fresh password login, face unlock, and password fallback with the camera
covered and key unplugged. Empty/wrong passwords must fail if neither hardware
method succeeds. No key is enrolled yet, so face/password behavior should remain
usable. See [authentication.md](authentication.md) for recovery details.

For the following provisioning commands use Bash (`bash`), not Fish syntax.

## 2. Enroll touch authentication

Run as **glom, not root**, from this repository. This registers a FIDO credential;
it does not overwrite the independent OpenPGP slots. Touch when the key flashes.
The origin/application ID must match the NixOS hostname, currently `nixos`.

```bash
(
  set -e
  umask 077
  # Stop rather than overwrite an existing enrollment or backup-key mapping.
  test ! -s users/glom/u2f_keys
  enrollment="$(mktemp)"
  trap 'rm -f "$enrollment"' EXIT
  pamu2fcfg -u "$USER" -o pam://nixos -i pam://nixos > "$enrollment"
  test -s "$enrollment"
  install -m 644 "$enrollment" users/glom/u2f_keys
)
```

Rebuild with `test` again to install the root-owned mapping. Cover the camera,
then test `sudo -k; sudo true`: after Howdy fails, touch should succeed without
the account password or FIDO PIN. For swaylock, press Enter, let Howdy fail, then
touch. Repeat with camera covered and key unplugged: the correct password must
work; incorrect and empty passwords must fail. Verify face authentication still
works without the key. Only then make the generation persistent with `switch`.

Enrollment is a manual hardware operation. Nix never enrolls automatically.
Changing the hostname requires matching origin/appid settings or re-enrollment.
Keep a separately enrolled spare key if possible; don't overwrite the original
mapping when adding one. The account password remains the recovery method.

## 3. Create and back up a new OpenPGP identity

This is an interactive key ceremony, not a script to run blindly. Use a trusted,
preferably offline environment. The primary certification key stays off the
YubiKey; separate signing, encryption, and authentication subkeys go on it.

**Before generating secrets:** arrange an already-mounted encrypted removable
backup volume, a strong key passphrase, and a secure place for its recovery
information. Use RAM-backed working directories with swap disabled or encrypted.
This laptop declares a swap partition without LUKS configuration: tmpfs alone
does not guarantee secrets cannot be swapped to disk. The Nix change does not
disable swap, disconnect networking, or establish an offline environment for you.
Stop if you cannot satisfy these conditions.

In Bash, after checking those prerequisites:

```bash
set -euo pipefail
workdir="$(mktemp -d "$XDG_RUNTIME_DIR/openpgp.XXXXXXXX")"
chmod 700 "$workdir"
# Copy only non-secret configuration, not the normal keyring. Temporary homes
# also need a working pinentry and shared PC/SC settings.
install -m 600 "$HOME/.gnupg/gpg-agent.conf" "$workdir/gpg-agent.conf"
install -m 600 "$HOME/.gnupg/scdaemon.conf" "$workdir/scdaemon.conf"
export GNUPGHOME="$workdir"

gpg --quick-generate-key 'Glom Zhao <me@glomzzz.com>' ed25519 cert 2y
gpg --list-keys --with-subkey-fingerprint
```

Record the **full primary fingerprint** in `PRIMARY` (no spaces). The name/email
above match this repository; change them before generation if inappropriate.
Use interactive pinentry; never pass a passphrase as a command argument.

```bash
PRIMARY=YOUR_FULL_PRIMARY_FINGERPRINT
gpg --quick-add-key "$PRIMARY" ed25519 sign 2y
gpg --quick-add-key "$PRIMARY" cv25519 encr 2y
gpg --quick-add-key "$PRIMARY" ed25519 auth 2y
gpg --list-secret-keys --with-subkey-fingerprint
```

Record the full fingerprints of the `[S]` and `[E]` subkeys as `SIGNING` and
`ENCRYPTION`, without a trailing `!`. These algorithms are supported by this
YubiKey. Expiration is intentional; renew before expiry and update/export the
public certificate as needed. Assign the real fingerprints, replacing these
placeholders before continuing:

```bash
SIGNING=YOUR_FULL_SIGNING_SUBKEY_FINGERPRINT
ENCRYPTION=YOUR_FULL_ENCRYPTION_SUBKEY_FINGERPRINT
```

Set `BACKUP` to a directory on your **already-mounted encrypted removable
volume**, outside this repository and outside the Nix store. Check the mount
before writing; don't accidentally create an unencrypted host directory.

```bash
umask 077
mkdir -p "$BACKUP"
chmod 700 "$BACKUP"
gpg --armor --export-secret-keys "$PRIMARY" > "$BACKUP/secret-keys.asc"
gpg --armor --export "$PRIMARY" > "$BACKUP/public.asc"
gpg --export-ownertrust > "$BACKUP/ownertrust.txt"
gpg --output "$BACKUP/revoke.asc" --gen-revoke "$PRIMARY"
```

The secret export must contain the primary and all three subkeys. Protect the
revocation certificate too: anyone who obtains it can revoke your identity.
Store a second secure backup if possible. Retain the passphrase separately.

### Verify the backup before touching the card

Restore into a second fresh RAM-backed directory and prove that the restored
signing and encryption keys work. This is the last easy recovery point before
`keytocard` replaces working subkeys with card references.

```bash
verifydir="$(mktemp -d "$XDG_RUNTIME_DIR/openpgp-verify.XXXXXXXX")"
chmod 700 "$verifydir"
install -m 600 "$workdir/gpg-agent.conf" "$verifydir/gpg-agent.conf"
gpg --homedir "$verifydir" --import "$BACKUP/secret-keys.asc"
gpg --homedir "$verifydir" --list-secret-keys --with-subkey-fingerprint

printf 'backup verification\n' > "$verifydir/check.txt"
gpg --homedir "$verifydir" --local-user "${SIGNING}!" --armor \
  --detach-sign "$verifydir/check.txt"
gpg --homedir "$verifydir" --verify "$verifydir/check.txt.asc" "$verifydir/check.txt"

# Trust bypass is scoped to this test of your own explicitly verified fingerprint.
gpg --homedir "$verifydir" --trust-model always --recipient "${ENCRYPTION}!" \
  --output "$verifydir/check.gpg" --encrypt "$verifydir/check.txt"
gpg --homedir "$verifydir" --output "$verifydir/decrypted.txt" \
  --decrypt "$verifydir/check.gpg"
cmp "$verifydir/check.txt" "$verifydir/decrypted.txt"
```

Confirm these succeed with your backup passphrase. Do not proceed after any
failure, missing subkey, or mismatched fingerprint. Keep the verified backups
unplugged/offline when no longer needed.

## 4. Move only the subkeys onto the YubiKey

First inspect `gpg --card-status` and `ykman openpgp info` again. Stop if any slot
is occupied unexpectedly; **do not reset the card**. Never overwrite an existing
key without a separately reviewed recovery plan.

Change the OpenPGP user PIN and admin PIN interactively, using the existing PINs:

```bash
ykman openpgp access change-pin
ykman openpgp access change-admin-pin
```

A factory-new key normally uses `123456` and `12345678` respectively, but an empty
card does not prove those PINs are unchanged. Do not guess repeatedly: retries
are limited. Keep both new PINs in your secure recovery records, not this repo.
The FIDO PIN, OpenPGP user PIN, and OpenPGP admin PIN are separate credentials.

Use the original working keyring (the shell's `GNUPGHOME` is still `$workdir`):

```bash
gpg --edit-key "$PRIMARY"
```

In the GPG prompt:

1. Inspect the displayed subkeys and fingerprints. `key N` toggles a subkey's
   selection; an asterisk marks it. Select **only the `[S]` signing subkey**.
2. Run `keytocard`, choose the **Signature** slot, and enter the admin PIN.
3. Deselect it with `key N`, then select **only `[E]`**. Run `keytocard` and choose
   **Encryption**.
4. Deselect it, select **only `[A]`**, run `keytocard`, and choose **Authentication**.
5. Run `save`. Never transfer the primary `[C]` certification key.

Subkey numbers depend on your keyring; do not copy guessed indices. After
`save`, the working subkeys should show `ssb>` references. The verified pre-transfer
backup remains essential: card private keys cannot be exported back out.

Enable touch for each OpenPGP operation, with reversible `on` policies:

```bash
ykman openpgp keys set-touch sig on
ykman openpgp keys set-touch dec on
ykman openpgp keys set-touch aut on
ykman openpgp info
```

Do not use `fixed`/`cached-fixed` casually: those policies cannot be disabled
without replacing/deleting the affected key. OpenPGP signing may require a user
PIN as well as touch; it is independent of the touch-only PAM configuration.

## 5. Install only public data and card references locally

Exported public data is already in `$BACKUP/public.asc`. Return to the normal
user keyring; do **not** import the secret backup into it:

```bash
unset GNUPGHOME
gpg --import "$BACKUP/public.asc"
gpg --card-status
gpg --list-secret-keys --with-subkey-fingerprint
```

Expect `sec#` for the unavailable primary secret and `ssb>` for card subkeys.
There should be no ordinary local `sec`/`ssb` private keys for this identity.
Test a detached signature using `--local-user "${SIGNING}!"`; verify it, then
confirm a new signing attempt fails with the YubiKey unplugged. Test encryption
and decryption of disposable data too, touching the key when requested.

From this repository, install the **public certificate only**:

```bash
install -D -m 644 "$BACKUP/public.asc" users/glom/keys/openpgp.asc
```

Edit `users/glom/openpgp.nix`:

```nix
{
  signingKey = "FULL_SIGNING_SUBKEY_FINGERPRINT!";
  publicKeyFile = ./keys/openpgp.asc;
}
```

Use the signing **subkey** fingerprint, including `!`, to pin the exact signing
key. Set both fields together. Run `jj status` so the new public file is tracked
by the colocated jj/Git flake, and review that no secrets appear in the changes.
Home Manager imports this public certificate with ultimate ownertrust
(appropriate only for your own verified identity). Re-run the checks, build,
and activate with `test`; then test real signing before `switch`.

Upload `public.asc` to GitHub's **GPG keys** settings if using GitHub, and ensure
`me@glomzzz.com` is verified there. Do not upload the secret backup or revoke.asc.
Use a disposable repository to test Git signing; in this jj workspace use jj
commands, not `git commit`. Jujutsu signs your commits on creation and rewrite;
`jj sign -r REV` signs an explicitly selected revision manually. Push also signs
any remaining unsigned mutable commits authored by you. Verify signatures locally
and on the hosting service.
No commit or push is performed by this configuration change.

Only after backups and card operations are verified, stop agents in the two
**temporary** keyrings and remove those directories. Check the variable values
first; never remove the normal `~/.gnupg` or your backups:

```bash
gpgconf --homedir "$workdir" --kill all
gpgconf --homedir "$verifydir" --kill all
rm -r -- "$workdir" "$verifydir"
unset workdir verifydir
```

If the card disappears or is busy, close ongoing GPG operations, run
`gpgconf --kill scdaemon`, and reinsert it; check `systemctl status pcscd.socket`.
The configured `disable-ccid`/`pcsc-shared` settings let GPG and ykman share PC/SC.
If `gpg --card-status` reports "Service is not running" while pcscd is active,
check `journalctl -u pcscd.service` for `NOT authorized` / `access_pcsc` errors.
Activate the targeted PC/SC polkit rule with `sudo nixos-rebuild test --flake .#nixos`,
then restart `scdaemon` and check card access before retrying signing. Do not run
signing commands as root or broaden permissions to unrelated polkit actions.
Private backups and revocation material must remain secure and available even
once daily signing works. System SOPS decryption continues using the host SSH
identity; it does not depend on the removable key.
