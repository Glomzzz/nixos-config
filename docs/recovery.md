# Generations and garbage collection

Automatic GC runs weekly with a randomized delay and prunes generations older
than 30 days. `just gc` uses the same policy; `just clean` only prunes system
profile history older than 30 days. Neither uses `--delete-old`.

Before the first GC run, preserve a generation verified to work on this laptop:

```bash
just pin-known-good
```

This creates `/nix/var/nix/gcroots/known-good-nixos` pointing at the **resolved
store path** of the running system, not the mutable `/run/current-system` link.
It keeps that system's closure alive even when its profile generation is pruned.
Only replace this pin after booting and validating its replacement, including
the internal panel, external monitor, Wi-Fi, suspend/resume, and authentication.

The GC root preserves store contents, not a permanent GRUB menu entry. Recent
profile generations remain bootable subject to GRUB's 20-entry limit. To restore
the pinned system from a working recovery/root shell:

```bash
sudo nix-env --profile /nix/var/nix/profiles/system \
  --set "$(readlink -f /nix/var/nix/gcroots/known-good-nixos)"
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

Use the bootloader's prior generation first when the current generation will not
boot. Store GC does not back up mutable application or personal data.

## Local Btrfs snapshots

Snapper takes hourly and boot-time read-only snapshots of the root `@` subvolume.
The setup service creates a private `/.snapshots` **nested subvolume** before any
Snapper service runs. It refuses to replace an existing non-subvolume directory
or follow a symlink. This requires root privilege during activation/boot; do not
run `snapper create-config`, since the configuration is already declarative.

Retention is 6 hourly, 7 daily, 4 weekly, and 2 monthly timeline snapshots, plus
up to 5 ordinary numbered snapshots (including boot snapshots). Cleanup runs
daily. Minimum-age rules mean counts are not strict instantaneous upper bounds.
Inspect both retention and free space after enabling:

```bash
sudo snapper -c root list
sudo systemctl status prepare-root-snapshots snapper-boot
systemctl list-timers 'snapper-*'
sudo btrfs filesystem usage /
```

Snapshots share disk blocks with the live filesystem; large file changes or game
updates can consume substantial space. Counts alone are not a disk-space budget.
Nested subvolumes, other filesystems, and FUSE mounts are **not** included.
On the current layout `/home` is an ordinary directory inside `@`, so local home
files are included, but the mounted Mac mini share and `/boot` are not.

For file recovery, copy only the needed files out of
`/.snapshots/NUMBER/snapshot/` using root privileges. Avoid blindly restoring the
entire running root (especially `/nix`) or using `snapper rollback`: this setup
uses an explicit `subvol=@` mount and does not configure automatic boot into
snapshots. System-generation rollback is the preferred way to undo NixOS changes.

**These snapshots are not off-device backups.** Disk failure, theft, or root-level
destruction can remove both originals and snapshots. An independent backup
repository remains to be configured; Syncthing is not a substitute.
