# Encrypted Mac mini backups

The `restic-backups-mac-mini.service` backs up `/home/glom` to
`sftp:glom@mac-mini:/Users/glom/Backups/nixos-restic`. Restic encrypts data and
metadata before upload. Retention is 7 daily, 4 weekly, and 12 monthly snapshots;
each successful run also prunes according to that policy and reads a random
5% subset during an integrity check. A check is not a restore test.

**Scheduling is disabled until provisioning and an initial restore are verified.**
No key/password is generated, no remote directory is created, and no backup or
prune runs as part of evaluation, building, committing, or activation. The manual
service remains available to complete setup. Once ready, set
`services.mac-mini-backup.enable = true` in the host and rebuild; this creates a
daily persistent timer with up to one hour of random delay.

## Scope

Included: documents, projects (including local unpushed history), mail, shell and
application settings, and other home data. Review the list before the first
large upload. Excluded:

- `~/.cache`, trash, and cache directories marked with `CACHEDIR.TAG`;
- `~/.local/share/Steam/steamapps` (including game-local saves there: copy any
  valuable non-cloud saves into a backed-up directory);
- `~/mnt` and other filesystems (`--one-file-system`), including remote mounts.

The system Nix store is reproducible and is not included. `/etc`, host SSH keys,
root-owned service data, and secrets outside the home directory are **not**
included. Preserve the host SOPS decryption identity and encryption recovery
material separately offline. Restic reads live files, not a transactional snapshot:
quiesce/export databases and other applications with multi-file consistency needs.
There is no claim that every live application database is consistent.

## Provisioning (manual, do not send credentials to chat)

1. On the Mac, prepare `/Users/glom/Backups/nixos-restic` on storage with enough
   space, enable its intended SSH/SFTP access, and verify that the volume is
   actually mounted. Do not silently fall back to the Mac's system disk when
   an external backup volume is absent. No remote operations are automated here.
2. Create a **separate backup-only** SSH identity on the laptop outside the
   repository/store, with the public key enrolled on the Mac for SFTP. Use a
   noninteractive key only for this purpose. Restrict it server-side to SFTP and
   disable forwarding/PTY; a dedicated remote account/storage boundary is better
   isolation than relying on a client flag. Never replace the YubiKey's SSH key.
   This configuration defaults to the requested existing `glom` account; an
   unrestricted account key can access more than the backup directory.
3. Verify the Mac's SSH host-key fingerprint through a trusted independent
   channel and install its pinned `mac-mini` host entry. Do not treat an
   unverified `ssh-keyscan` result as authentication or disable strict checking.
4. Provision these regular files in a root-owned mode-0700 directory
   `/var/lib/nixos-backup/`, each mode **0600**, without putting contents in argv,
   shell history, Nix expressions, or this repository:
   - `password`: a strong, unique Restic repository password;
   - `ssh-key`: the separate unattended SSH private key;
   - `known-hosts`: the verified host entry for `mac-mini`.

Systemd loads private copies with `LoadCredential` and runs Restic as `glom`.
The SSH adapter uses batch mode, only that identity, no agent, strict host-key
checking, and the existing LAN/Tailscale route helper. Missing credentials or
host verification fail rather than prompting a background YubiKey operation.
The root credential files persist in plaintext on the current unencrypted disk:
this is not an offline-security boundary. Maintain offline copies of the password
and key before trusting the backup. Losing the password loses the repository.

## Initial backup and restore test

After building/reviewing and activating the configuration, initialize deliberately
only when the destination is known to be correct:

```sh
sudo nixos-backup init
sudo systemctl start restic-backups-mac-mini.service
journalctl -u restic-backups-mac-mini.service
sudo nixos-backup snapshots
sudo nixos-backup check --read-data
```

The helper uses a transient systemd service so credentials are never exposed in
the command line. It accepts ordinary Restic subcommands and does not enable the
timer. Do not run destructive maintenance concurrently with a backup; normal
Restic repository locking applies. It never automatically removes active locks.

Restore one chosen important file into a **new empty local directory**, not over
the original:

```sh
mkdir -m 700 ~/restic-restore-test
sudo nixos-backup restore latest --target /home/glom/restic-restore-test \
  --include /home/glom/Documents/CHOSEN_FILE
```

Replace `CHOSEN_FILE` with an actual backed-up path; compare the restored bytes
with the original under `~/restic-restore-test/home/glom/Documents/`. Run the
same exercise from recovery media/a separate machine using the offline
password, SSH identity, verified host key, and correct remote path. Do not mark
setup complete until that recovery path has worked. Keep a second offline or
immutable copy where practical: a compromised client with SFTP write access can
delete its repository; Restic encryption alone does not prevent deletion.

## Operation

After enabling and activating the timer:

```sh
systemctl list-timers restic-backups-mac-mini.timer
systemctl status restic-backups-mac-mini.service
journalctl -u restic-backups-mac-mini.service
```

Failures remain in the journal and attempt a desktop notification when the user
bus is available. A sleeping/offline Mac causes a failure, not a local fallback;
rerun manually when it becomes available. Check backup freshness regularly and
perform periodic restore tests; desktop notifications are not an off-device
monitoring service and cannot report a dead laptop.

`checks.x86_64-linux.backups` exercises initialization, backup, exclusions,
retention, a full integrity check, and a byte-for-byte restore using an isolated
local repository and synthetic files. It never connects to the Mac or reads real
credentials. Real SFTP enrollment and off-device restoration remain manual gates.
