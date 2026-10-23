# YubiKey-backed SSH

SSH uses the existing OpenPGP **authentication** subkey, not the signing key.
`users/glom/ssh/yubikey-openpgp.pub` is exported from the exact fingerprint in
`users/glom/openpgp.nix`. It is public data, safe for this repository/Nix store.
No private SSH key is generated or copied to disk.

Home Manager enables `gpg-agent`'s SSH socket and exports `SSH_AUTH_SOCK` to
shells, systemd user services, and D-Bus. Other configured SSH agents remain
disabled. `~/.ssh/config` selects `~/.ssh/yubikey-openpgp.pub` with
`IdentitiesOnly yes`; the matching private-key operation goes through the card.
Agent forwarding is disabled. Existing Mac mini routing is unchanged.

## Activate and enroll remote accounts

Build/test the system before switching. After activation, log out and back in
so the desktop, shells, and background services agree on the agent socket. Do
not kill a busy GPG agent during signing or decryption.

Discover the existing card and inspect **public** identities:

```sh
gpg --card-status
ssh-add -L
ssh-keygen -lf ~/.ssh/yubikey-openpgp.pub
```

Install the contents of `~/.ssh/yubikey-openpgp.pub` in each remote account's
`authorized_keys`, or in GitHub/GitLab's **authentication SSH keys** settings.
Uploading a GPG signing certificate does not enroll an SSH authentication key.
Remote-account changes are deliberately not automated by Nix activation.

Before removing any old remote key, verify an actual connection using only
public-key authentication:

```sh
ssh -o PreferredAuthentications=publickey -o PasswordAuthentication=no HOST
```

The key's OpenPGP PIN may be requested; touch is required for authentication.
Repeat with the YubiKey removed: public-key authentication must fail. Do not
accept an unexpected host key while testing.

## Recovery and boundaries

The new default public-key identity will not work on a remote account until it
is enrolled there. Keep the established remote recovery method while testing.
To use an existing software key deliberately, add `-i /path/to/existing/key`;
to completely bypass the managed config for recovery, use `ssh -F /dev/null`
with the required identity, hostname, proxy, and other connection options.

This config does not modify remote servers or remove the laptop's existing
inbound `authorized_keys`. The laptop's SSH server continues its existing
key-only policy. Password-capable remote servers may still offer password
fallback unless the client command above disables it explicitly. Do not claim
hardware-only access until old keys/password methods are removed on that server.

GPG automatically offers the inserted card's authentication key; importing it
with `ssh-add ~/.ssh/id_ed25519` is not necessary and would introduce a software
key. Do not put private keys or PINs in `sshcontrol` or Nix configuration.

Regression checks compare the checked-in SSH public key with an export of the
exact authentication subkey in an isolated public-only keyring:

```sh
nix build --no-link .#checks.x86_64-linux.openpgp
```
