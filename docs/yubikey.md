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
- Home Manager configures GnuPG, a socket-activated agent, a saved-user-PIN
  provider with Qt fallback, and exclusive PC/SC access to preserve PIN
  verification between operations. Automatic entry is available only after
  explicitly enrolling the separate host-encrypted PIN below. Release
  GPG's card connection before OpenPGP management with `ykman` (see below).
  Its SSH socket uses the card's authentication subkey;
  [SSH setup](ssh.md) covers installing the public key on remote accounts.
- Git/Jujutsu signing stays **disabled until provisioned**. Once both fields in
  `users/glom/openpgp.nix` are set, the public certificate is imported, and GnuPG,
  Git, and Jujutsu all select the same exact signing subkey. Git signs commits/tags
  by default. Jujutsu uses `signing.behavior = "drop"`: it creates and rewrites
  commits unsigned, and `git.sign-on-push` signs the unsigned outgoing mutable commits
  authored by you when you run `jj git push`. One touch covers that push's signatures
  only because the `sig` touch policy is `cached` (about 15 s). Plain `git push` does
  not sign. `jj sign -r REV` can sign an explicitly selected revision manually.
  Signing changes commit hashes; review the outgoing stack before pushing.

### Touch notifications

The graphical session runs `yubikey-touch-detector` with requester attribution.
A critical, transient notification says **`WHO requires a yubikey touch`** and is
closed when the request ends (touch, cancellation, timeout, or device removal).
It covers OpenPGP signing/decryption, SSH through gpg-agent, FIDO/U2F/WebAuthn
(including browsers and PAM), and HMAC challenge-response. It does not change
card touch policies, PIN handling, authentication order, or password fallback.

- OpenPGP and SSH use the agent socket's kernel peer credentials. For a GPG child,
  the immediate parent is named where useful (e.g. `git` or `jj`); an interactive
  shell is not mistaken for the requester.
- FIDO uses actual presence-needed HID reports. Writable device descriptors give
  a **best-effort application name**, e.g. `firefox`. The website/RP name is not
  exposed by those reports. Multiple openers, inaccessible process metadata, or
  simultaneous requests fall back to **`FIDO/WebAuthn`**, not a guessed app.
- PAM opens/closes empty, root-owned `/run/yubikey-touch/glom/{sudo,swaylock}`
  markers to supply service names without granting the notifier root privileges.
  Markers alone never trigger a notification; a FIDO touch-wait event is required.
- Unattributable OpenPGP/SSH requests use **`OpenPGP/SSH`**; HMAC uses
  **`HMAC challenge-response`**. OpenPGP/SSH touch detection is a pending-operation
  heuristic, not a hardware guarantee; short/cached operations are filtered and
  reported pinentry waits are excluded.

These labels are informational, **not trusted proof of the requesting app**.
Only touch for an operation you initiated. No PINs, command-line arguments,
OpenPGP payloads, or browser URLs are collected by the attribution code.
Notifications may be hidden while the screen is locked; this does not bypass
swaylock or put authentication information above its secure surface.

After rebuilding, log out/in (or restart the user service once the graphical
session is active), then test a signed commit, SSH, a browser security-key login,
and `sudo -k; sudo true`. Cover the camera so sudo reaches U2F. Verify the title,
then touch/cancel and check that the popup disappears. An unplugged key must not
leave a pending notification or prevent password fallback.

```sh
systemctl --user status yubikey-touch-detector.service
journalctl --user -u yubikey-touch-detector.service -b
nix build --no-link .#checks.x86_64-linux.yubikey-touch .#checks.x86_64-linux.authentication
```

Stop/restart the detector gracefully: it proxies the local GPG and SSH agent
sockets and restores them on termination. Do not run a second copy alongside the
user service or kill it with `SIGKILL`. The tests use a private D-Bus session,
private sockets, and fake process metadata. They verify requester labels,
notification creation/replacement/closure, and critical/transient hints without
prompting for touches or altering the live agent.

Public FIDO enrollment records and OpenPGP public certificates may live in this
repository/Nix store. **Never add private keys, secret-key exports, revocation
certificates, plaintext PINs, or passphrases.** The optional encrypted user PIN
below is a deliberate convenience exception, not a private-key backup.
Nix does not provision private keys.

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
# also need a working pinentry and the same PC/SC settings.
install -m 600 "$HOME/.gnupg/gpg-agent.conf" "$workdir/gpg-agent.conf"
install -m 600 "$HOME/.gnupg/scdaemon.conf" "$workdir/scdaemon.conf"
export GNUPGHOME="$workdir"

gpg --quick-generate-key 'YOUR NAME <your-address@example.org>' ed25519 cert 2y
gpg --list-keys --with-subkey-fingerprint
```

Record the **full primary fingerprint** in `PRIMARY` (no spaces). The name/email
above are placeholders; replace them before generation.
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

First inspect `gpg --card-status`, release that keyring's card connection with
`gpgconf --kill scdaemon`, then inspect `ykman openpgp info` again. Stop if any
slot is occupied unexpectedly; **do not reset the card**. Never overwrite an
existing key without a separately reviewed recovery plan. If another keyring
holds the card, release its scdaemon too, using an explicit `--homedir` (see below).

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

Release the working keyring's card connection, then enable touch for each
OpenPGP operation, with reversible `on` policies:

```bash
gpgconf --kill scdaemon
ykman openpgp keys set-touch sig cached
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
your address is verified there. Do not upload the secret backup or revoke.asc.
Use a disposable repository to test Git signing; in this jj workspace use jj
commands, not `git commit`. Jujutsu leaves new commits unsigned; `jj git push`
signs unsigned outgoing mutable commits authored by you. `jj sign -r REV` signs an
explicitly selected revision manually. Verify signatures locally
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

## PIN retention and card-management access

The inspected card uses **Signature PIN: not forced** (`ykman` calls this
**Require PIN for signature: Once**) touch policy **On** for `dec` and `aut`, and **Cached** (15 s) for `sig`.
With that PIN policy, consecutive signatures should not need a newly typed PIN
while the card's verification state remains intact. Touch is still required, but
a `sig` touch covers signatures for about 15 seconds. Unplugging, a card reset, or restarting scdaemon can require the
PIN again; signing and decryption/SSH can also need separate initial verification.
Ordinary `gpg-agent` passphrase-cache TTLs do not reliably control this card state.

`disable-ccid` keeps GPG on the PC/SC backend; `pcsc-shared` is deliberately absent.
Shared access has a [reported repeated-PIN problem](https://dev.gnupg.org/T7041),
and another smart-card client can invalidate the state GPG relies on. Generic
desktop password caching remains disabled. Jujutsu does not sign local snapshots
or rewrites; signing happens at push. Exclusive access does not change the card's PIN/touch
policies. The separate saved-PIN opt-in below deliberately automates user-PIN
entry; it is not enabled by the `no-allow-external-cache` setting.

Exclusive access means `ykman openpgp` and other smart-card clients cannot use the
card while GPG holds it. When all signing, decryption, and SSH authentication
operations are idle, release the connection **before** using those tools:

```bash
gpgconf --homedir "$HOME/.gnupg" --kill scdaemon
ykman openpgp info
```

The next GPG operation starts scdaemon again. Do not run `ykman` between signatures
when testing PIN retention. FIDO browser/PAM authentication uses a separate
interface and does not need this release procedure.

Each GnuPG home can have its own agent/scdaemon. If a public-only Emacs package
verification keyring has acquired the card, release its connection while package
operations are idle:

```bash
gpgconf --homedir "$HOME/.cache/emacs/elpa/gnupg" --kill scdaemon
```

Likewise, release the previously active keyring's scdaemon before using a
provisioning/verification keyring. Do not delete keyrings or kill an agent that is
performing an operation. Repeated interference from a public-only keyring should
be fixed by preventing its card access, not by weakening the card PIN policy.

After activating this configuration with `nixos-rebuild test`, restart the normal
keyring's scdaemon using the command above so it reads the new settings. Test two
signatures outside the repository, using the configured default signing subkey:

```bash
(
  set -e
  probe="$(mktemp -d)"
  trap 'rm -r -- "$probe"' EXIT
  printf 'PIN retention test\n' > "$probe/message"
  gpg --output "$probe/first.sig" --detach-sign "$probe/message"
  gpg --verify "$probe/first.sig" "$probe/message"
  gpg --output "$probe/second.sig" --detach-sign "$probe/message"
  gpg --verify "$probe/second.sig" "$probe/message"
)
```

Enter the user PIN in pinentry if requested and touch once. The second signature
should not need another PIN entry; it needs a new touch only if it runs more than
15 seconds after the first touch. Cancel rather than
guess if unsure of the PIN. If the second operation still asks, inspect
`journalctl --user -u gpg-agent.service` and other running smart-card clients;
exclusive access is a candidate fix, not proof that every reset source is gone.
The automated OpenPGP check validates configuration/public data and exercises
the PIN provider with fake secrets/devices, not hardware PIN retention.

## Optional host-decryptable user PIN

This account explicitly opts into automatic entry from
`~/nixos-secrets/secrets/hosts/nixos-yubikey-pin.yaml`, encrypted **only** to the existing host
age recipient. It must not be encrypted to the YubiKey it unlocks. Other user
credentials retain their OpenPGP-only recipients. Only the existing OpenPGP
**user** PIN is enrolled; admin, FIDO, reset-code, and new-PIN prompts stay manual.

**Security trade-off:** the laptop can recover this PIN without the YubiKey.
The host SSH private key and this machine's unencrypted disk/swap do not protect
it against offline disk access. A process running as this user can also read
the runtime PIN. Private keys still remain on the card, and its touch policies
are unchanged. Full-disk/swap encryption is still needed; tmpfs is not proof
that plaintext never reaches disk. This is convenience, not independent PIN
protection or isolation between processes sharing the UID.

From a local Bash terminal in this repository, enroll with hidden input:

```bash
python3 modules/home/programs/dev/yubikey-pin/provision.py \
  --sops-program "$(command -v sops)" --hostname nixos \
  --repo "$HOME/nixos-secrets"
```

After installation, `sops-save-yubikey-pin` is the equivalent command; it writes
into `~/nixos-secrets` by default. Enter the
current user PIN twice; the command does not change or verify the card PIN. It
refuses nonterminal input and existing targets unless `--replace` is explicit.
Only ciphertext is written, atomically; the PIN travels to SOPS via stdin, never
argv, environment, a plaintext editor file, or output. Never paste it into chat
or run a command that prints the runtime secret. A typo can still consume a card
retry during the first real use: cancel instead of repeatedly guessing.

Review only the encrypted diff in `~/nixos-secrets` and push that repository
before evaluating this flake. Build
and activate safely:

```bash
nix build --no-link .#checks.x86_64-linux.openpgp \
  .#checks.x86_64-linux.sops .#checks.x86_64-linux.credentials
sudo nixos-rebuild build --flake .#nixos
sudo nixos-rebuild test --flake .#nixos
```

Until the encrypted PIN exists, Nix omits its secret declaration and the provider
uses Qt normally. Once enrolled, sops-nix installs
`/run/secrets/yubikey/openpgp-user-pin`, owned by `glom` with mode `0400`. Nix
copies only ciphertext and helper code to the store: it never evaluates the
plaintext PIN or embeds it in a derivation. After activation, when no GPG/SSH
operation is busy, restart the agent so it uses the new pinentry program:

```bash
gpgconf --homedir "$HOME/.cache/emacs/elpa/gnupg" --kill scdaemon
gpgconf --homedir "$HOME/.gnupg" --kill gpg-agent
```

Use the disposable two-signature test above, leaving normal pinentry mode
(`ask`): the first unlock should obtain the saved PIN without a dialog, and
touch is requested only when the 15 s `sig` cache has expired. `--pinentry-mode error` intentionally
forbids **any** PIN provider and therefore is unsuitable for testing an initial
automatic unlock. It remains useful to test subsequent on-card verification.

The provider accepts only the expected English OpenPGP user-PIN prompt and
configured public card serial, with a private, bounded runtime PIN file. Admin,
new/repeated PIN, software-key, error, low-remaining-attempt, unknown/localized,
and explicitly redirected prompts are delegated to Qt. Generic Qt external
password caching is disabled even if a client requests it. Matching prompt text
is a scope check, not authentication against a malicious same-UID client.

### Stale PIN and conservative fallback

Pinentry cannot reliably observe card verification results. Before an automatic
submission, the helper records **nonsecret** attempt metadata under
`$XDG_RUNTIME_DIR/yubikey-pin/` (private directory/files). It will not replay the
same saved PIN unless the signature counter has advanced, the secret was
replaced, or the USB device was reconnected. No PIN or PIN hash is stored there.
Concurrent requests use a lock. Thus a stale saved PIN is not repeatedly retried
against an unchanged card context; remaining-attempt warnings always use Qt.

An authentication/decryption prompt without a signature counter is limited to
one automatic attempt per USB connection/secret version. Restarting scdaemon
without a successful intervening signature can therefore deliberately fall back
to manual entry. Ambiguous multiple YubiKeys or unavailable USB metadata also
fall back. This guard favors avoiding a lockout over guaranteeing touch-only
behavior in every recovery situation. Replugging/rebooting can permit a new
attempt, so do not use those actions to repeatedly retry a suspected stale PIN.

If automatic entry fails, fix the enrolled value locally with
`sops-save-yubikey-pin --replace`, then rebuild/test. This does **not** change the
card PIN. If the card PIN itself was changed, the stored value must be updated
separately. Never save the admin PIN as a workaround. Removing this dedicated
encrypted file and rebuilding disables saved entry; do not delete other secrets
or the hardware keys. Historical encrypted PIN copies remain decryptable to the
host key: change the card's user PIN to revoke old copies, using a separately
reviewed recovery procedure and without exhausting retries.

If the card disappears or is busy, close ongoing GPG operations, release the
relevant scdaemon, and reinsert it; check `systemctl status pcscd.socket`.
If `gpg --card-status` reports "Service is not running" while pcscd is active,
check `journalctl -u pcscd.service` for `NOT authorized` / `access_pcsc` errors.
Activate the targeted PC/SC polkit rule with `sudo nixos-rebuild test --flake .#nixos`,
then restart `scdaemon` and check card access before retrying signing. Do not run
signing commands as root or broaden permissions to unrelated polkit actions.
Private backups and revocation material must remain secure and available even
once daily signing works. System SOPS decryption continues using the host SSH
identity; it does not depend on the removable key.
