# Emacs mail: Infomaniak, mu4e, mbsync, and msmtp

The account is **Glom Zhao <me@glomzzz.com>**. Configuration lives in:

- `modules/home/programs/mail/default.nix`: Home Manager account, programs, sync timer.
- `~/.config/emacs/modules/feat/mail.el`: lazy mu4e UI and msmtp sending.
- `~/.password-store/email/infomaniak.gpg`: encrypted mailbox password, **not in this repository**.
- `~/Maildir/infomaniak/`: synchronized mail, with private directory permissions.
- `~/.cache/mu/`: the local index (Home Manager exports `MUHOME`).

The existing `gpg-agent`/Qt pinentry and YubiKey encryption subkey are reused.
No keys, PIN policies, or agent cache lifetimes are changed. The mail password is
separate from the Infomaniak account login password: use the mailbox-specific
password/device password required by Infomaniak for external mail clients.

## First-time setup

Apply the configuration from this repository (requires local sudo authentication):

```sh
sudo nixos-rebuild switch --flake ~/nixos-config#nixos
```

Then enter the mailbox password **locally in your terminal**, not in chat or a
Nix file. Use a single-line pass entry containing only the password; do not append
notes or other metadata.

```sh
export PASSWORD_STORE_DIR="$HOME/.password-store"
# Only for a new password store. Do not reinitialize an existing store casually.
pass init AE7977EF0356263C91F34C5D99A8A2212CBE37ED
pass insert email/infomaniak

# Verify decryption without printing the password; insert/unlock the YubiKey.
pass show email/infomaniak >/dev/null

# List remote folders before the first synchronization.
mbsync --list --all

# Use the service, rather than a parallel mbsync process, for the first sync.
# This may take time for a large mailbox. systemd serializes service starts.
systemctl --user start mbsync.service
find ~/Maildir/infomaniak -type d -name cur -printf '%h\n'
```

The timer runs every five minutes while the user systemd manager is active and
catches up after missed runs. It skips synchronization until the encrypted pass
entry exists. It can still fail or wait for pinentry when the card is absent or
locked; unattended sync is not guaranteed with a hardware-backed encryption key.
A job times out after 15 minutes. To retry after unlocking:

```sh
systemctl --user start mbsync.service
journalctl --user -u mbsync.service -n 50
systemctl --user status mbsync.timer
```

Home Manager initializes mu for `~/Maildir` and the configured personal address.
No manual `mu init` is needed. Restart Emacs after the rebuild when convenient
(save your work first):

```sh
systemctl --user restart emacs.service
```

Open **`C-c M`** (`M-x mu4e`). The existing **`C-c m`** remains `consult-man`.
mu4e starts indexing immediately and every five minutes while running. Use
`M-x mu4e-update-index` to refresh immediately after an external sync.

## Verify special folders before composing or moving mail

The completed setup on this machine uses the following saved mappings:

| Role | Local mu4e folder |
| --- | --- |
| Sent | `/infomaniak/Sent` |
| Drafts | `/infomaniak/Drafts` |
| Trash | `/infomaniak/Trash` |
| Archive | `/infomaniak/Archives` |

Sent, Drafts, and Trash were verified against the server's IMAP special-use
flags; Archives was explicitly confirmed by the user. IMAP synchronization and
SMTP STARTTLS authentication succeeded. No test message was sent automatically.

Folder names are intentionally **not guessed**. Read/search works without
mappings; compose (including replies), sent-copy filing, trash, and archive
require their corresponding verified folder.

1. Check the Sent, Drafts, Trash, and Archive roles in Infomaniak webmail.
2. Complete the first sync and index update in mu4e. If a role has no folder,
   create/assign it in webmail, sync, and update the index again.
3. Run **`M-x mail/configure-folders`** in Emacs and select the matching local
   folders (for example `/infomaniak/Sent`, **only if that is your real folder**).
4. Confirm saving. The mappings are saved in Emacs' existing Customize file,
   `~/.cache/emacs/custom.el`, not in the Nix store.

The folder getters refuse an unset mapping, a different account prefix, parent
traversal, or a folder missing `cur`, `new`, or `tmp`. They do not create guessed
folders. This guards the special-folder shortcuts, not arbitrary manual moves
or mu4e's explicit permanent-delete command.

mu4e keeps a Sent copy (`mu4e-sent-messages-behavior = sent`). Test sending and
replying to an address you control, then run another sync and check webmail.
If the provider also saves sent messages automatically, verify duplication before
considering a different sent-copy policy. Nothing sends a test message automatically.

## Authentication troubleshooting

If mbsync reports `Invalid login or password`, the IMAP connection reached the
server but authentication failed. Stop the timer while troubleshooting to avoid
repeated rejected logins:

```sh
systemctl --user stop mbsync.timer
```

For a domain Mail Service, use **Infomaniak Manager → Mail Service → your domain
→ the exact mailbox → Devices → Add a device**. Create a device such as
"Emacs on NixOS", generate a password, and **save it at the bottom of the page**.
Use that generated password, not the Manager login password. See
[Infomaniak's device-password guide](https://www.infomaniak.com/en/support/faq/1321).

```sh
pass insert --force email/infomaniak
systemctl --user reset-failed mbsync.service
systemctl --user start mbsync.service
# Only resume automatic attempts once the manual sync succeeds:
systemctl --user start mbsync.timer
```

A runtime-stopped timer remains declaratively enabled and can start again after
a later activation or login. SMTP `msmtp --serverinfo --account=infomaniak`
checks server capabilities/TLS without sending mail; success does not validate
the SMTP password or prove delivery.

## Synchronization and deletion policy

- IMAP: `mail.infomaniak.com:993`, implicit TLS with certificate validation.
- SMTP: `mail.infomaniak.com:587`, authenticated STARTTLS with certificate validation.
- mbsync: all folders, `SubFolders Verbatim`, create local folders only.
- `Remove None` and `Expunge None`: do not propagate mailbox removal or perform
  expunges. **This is not a read-only mirror or a backup**: message and flag
  changes still synchronize. In particular, deletion flags can propagate and
  another client/server can expunge them. Use care with move/delete operations.
- msmtp submits mail directly; there is no offline outgoing-message queue.
- systemd only runs mbsync. There is deliberately no post-sync `mu index` process
  to compete with the database lock held by mu4e. Closed mu4e means sync continues
  but indexing waits until mu4e opens again. `mu index` is safe manually only
  when no mu4e instance owns that database.

mu and mu4e are supplied together by the pinned Nix packages. Do not install a
second mu4e with ELPA/MELPA. Home Manager generates `~/.config/isyncrc`, with
`~/.mbsyncrc` linked to it for isync 1.5's default config lookup; msmtp uses
`~/.config/msmtp/config`.

Maildir messages and index contents are **not encrypted at rest by this setup**.
Directory permissions protect against other ordinary local users, not disk theft
or root. Use encrypted storage and a separate encrypted backup. Do not sync mu's
database between machines; index each machine's own Maildir.

## Offline validation

```sh
nix build --no-link ~/nixos-config#checks.x86_64-linux.mail
nix flake check --no-build ~/nixos-config
cd ~/.config/emacs
emacs --batch -Q -l tests/run.el
```

These checks use synthetic messages and do not retrieve real mail, decrypt
credentials, or send messages. The Emacs suite exercises mu4e-specific checks
when the Nix-managed mu4e package is on its load path.
