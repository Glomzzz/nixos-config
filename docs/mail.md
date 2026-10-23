# Emacs mail: Infomaniak, mu4e, mbsync, and msmtp

The account identity is supplied by the private secrets flake. Configuration lives in:

- `modules/home/programs/mail/default.nix`: Home Manager account, programs, sync timer.
- `~/.config/emacs/modules/feat/mail.el`: lazy mu4e UI and msmtp sending.
- GNOME Keyring's encrypted **Login** collection: live mailbox credential.
- `~/.password-store/email/infomaniak.gpg`: optional YubiKey-encrypted backup, **not in this repository**.
- `~/Maildir/infomaniak/`: synchronized mail, with private directory permissions.
- `~/.cache/mu/`: the local index (Home Manager exports `MUHOME`).

Both fetching and ordinary SMTP sending use the encrypted Login keyring, not
the YubiKey. Password login already unlocks this keyring through PAM. The GPG
keys, YubiKey PIN/touch policies, and agent cache lifetimes are unchanged; `pass`
is retained for explicit import and backup only. The mail password is separate
from the Infomaniak Manager login password: use a mailbox-specific device
password for external mail clients.

## First-time setup

Apply the configuration from this repository (requires local sudo authentication):

```sh
sudo nixos-rebuild switch --flake ~/nixos-config#nixos
```

Ensure the Login keyring has a **non-empty password**, ideally matching your
account login password; see [keyring setup](authentication.md#set-a-non-empty-keyring-password).
The helper refuses a plaintext keyring and never changes its password.

Enter the mailbox device password **locally in your terminal**, not in chat,
command arguments, an environment variable, or a Nix file:

```sh
# Hidden input; stores only this mailbox's credential in the Login collection.
infomaniak-password store

# OR migrate the existing pass entry once (requires the YubiKey for this step).
# Nothing prints the password; the encrypted pass entry is not changed/deleted.
infomaniak-password import-pass

# Verify availability without printing the password or prompting for unlock.
infomaniak-password check

# List remote folders before the first synchronization.
mbsync --list --all

# Use the service, rather than a parallel mbsync process, for the first sync.
# This may take time for a large mailbox. systemd serializes service starts.
systemctl --user start mbsync.service
find ~/Maildir/infomaniak -type d -name cur -printf '%h\n'
```

The timer runs every five minutes while the user systemd manager is active and
catches up after missed runs. An `ExecCondition` checks the credential without
printing it: if the Login keyring is locked or its mailbox entry is missing,
that attempt is skipped. No background password/PIN prompt or GPG fallback is
allowed. The next timer tick tries again; a running sync times out after 15
minutes. To retry after unlocking the Login keyring:

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
mu4e starts indexing immediately and every five minutes while running. These
are independent timers, so new upstream mail can take nearly ten minutes to
appear in the UI, plus synchronization time/scheduling delays. Use
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

## Background sending

In a mu4e compose buffer, **`C-c C-c`** sends and closes the draft on success;
**`C-c C-s`** sends but keeps the buffer. The source configuration's local
`~/.config/emacs/pkgs/mail-async.el` package runs msmtp in a background process.
SMTP network traffic and password/PIN waiting no longer block Emacs. No new
Nix package or outgoing service is needed.

The draft is read-only with `[sending mail]` in the mode line while submission
is pending. Sent filing, reply flags, and draft cleanup run only after msmtp
reports success. Failure keeps the draft editable and opens a `*Mail delivery*`
error buffer; there are no automatic retries. Use `M-x mail-async/status` to
inspect a pending draft's log or `M-x mail-async/cancel` to stop its process
with an explicit warning. Cancellation or a lost connection can leave delivery
uncertain: check before retrying. If SMTP accepted mail but local Sent filing
failed, sending again is blocked; recover the Sent copy locally rather than
resubmit the message.

Message's MIME preparation, attachment reads/encoding, and OpenPGP message
signing/encryption still happen in Emacs before the background transport starts.
Large messages can therefore still pause during preparation. This is not an
outgoing queue: wait for pending sends before exiting/restarting Emacs. Staging
uses a mode-600 temporary file, removed on normal success, failure, or process
cancellation; a forced Emacs shutdown can leave a private orphaned file.

## Credential security and unlocking

`infomaniak-password` defaults to a silent availability check. Its `lookup`
subcommand is for mbsync/msmtp and intentionally writes the password to their
pipe; do not run `lookup` directly in a terminal or include it in diagnostic logs.
The provider targets GNOME's persistent Login collection explicitly, not a
session/default collection, and checks its encrypted on-disk format. The item
is matched by application `nixos-mail`, service `infomaniak`, and the email
account. No password or decryption key enters a Nix derivation or repository.

A password login unlocks Login automatically only when the keyring password
matches the login password. Otherwise unlock it manually in **Passwords and
Keys** (`seahorse`). Screen locking does not necessarily lock the keyring;
fetching can continue while it remains unlocked. Conversely, face/YubiKey screen
unlocking cannot unlock a separately locked keyring. No successful fetch is
promised before login or while the keyring is locked.

The security boundary is the unlocked user session: software running as your
user can potentially retrieve its secrets, and root can compromise it. This
is less restrictive than requiring a physical YubiKey for each decryption. The
mailbox password is independently revocable. Protect the Login keyring with a
strong non-empty password; full-disk encryption and encrypted backups remain
recommended. The retained pass backup is optional, never a runtime dependency.
OpenPGP message signing/encryption may still use the YubiKey separately.

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
infomaniak-password store
# If you retain the pass backup, update it separately to avoid a stale backup:
# pass insert --force email/infomaniak
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

These checks use synthetic messages and mocked keyrings; they do not retrieve
real mail, decrypt real credentials, or send messages. Provider tests cover
locked/missing/plaintext keyrings, silent checks, explicit import, and rejection
of empty/ambiguous credentials without automatic unlock or GPG fallback. The Emacs suite exercises mu4e-specific checks
when the Nix-managed mu4e package is on its load path. Its background-send tests
use a gated fake SMTP executable to exercise real process success, rejection,
termination, MIME attachments, and delayed Sent filing without sending mail.
