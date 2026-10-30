# Disk and swap encryption migration gate

**Current state:** the root Btrfs filesystem, swap partition, and hibernation
image are unencrypted. Nothing in this change reformats, repartitions,
reencrypts, or moves data. Adding a LUKS option to an existing unencrypted device
is not an encryption migration and would make the next boot fail.

Keep this as a separately approved maintenance operation, not an ordinary
`nixos-rebuild switch`. The configuration also dual-boots Windows from another
drive, so preserve that drive and its recovery material independently.

## Prerequisites

- Provision the Mac mini backup and restore real files on another machine as
  described in [backups.md](backups.md). Record exclusions and copy any additional
  game saves, root-owned service data, and host keys that must survive.
- Keep the Restic password, backup SSH identity, host-key fingerprint, operator
  recovery keys, and host SOPS identity offline—not solely inside the encrypted
  backup or on the laptop being migrated. Never commit them to this repository.
- Prepare bootable recovery media, verify it can see the correct drives, and
  record the present partition/subvolume layout and GRUB/EFI arrangement.
- Choose and approve either backup/reinstall/restore onto LUKS-backed storage or
  an expert-reviewed in-place migration. Do not assume an in-place conversion is
  safe or supported for this exact layout; no such conversion is automated here.

## Target design to decide before maintenance

1. Root Btrfs lives inside a LUKS container opened by the initrd; filesystem
   declarations refer to the post-unlock device/subvolumes. Preserve the chosen
   NixOS/Home Manager compatibility baselines rather than resetting them merely
   because storage changed.
2. Decide whether to separate `/nix`, home data, snapshots, and high-churn data
   into subvolumes. Recheck snapshot/backup scope; nested subvolumes are not
   recursively included in a root snapshot.
3. Encrypt swap as well as root. With hibernation enabled, swap must be available
   with a recoverable persistent encryption key at resume time. Random-key
   per-boot encrypted swap cannot resume the previous boot's image. Confirm the
   new resume device and available capacity before retaining UPower's Hibernate
   action.
4. Plan an interactive boot passphrase and offline recovery method first.
   Optional TPM/FIDO enrollment is a later decision, not a substitute for tested
   recovery. Keep unrelated API/backup credentials out of initrd/Nix expressions.
5. EFI boot files remain outside ordinary root encryption. Secure Boot/measured
   boot is a separate policy/migration; disk encryption alone does not establish
   boot-chain integrity. Verify GRUB/initrd support for the selected container
   layout rather than copying settings intended for another bootloader.

## Acceptance tests before relying on the migrated system

Boot normally and via recovery media; unlock without network access; verify
filesystem mounts, user data, host SOPS decryption, login, and a previous known-good
system generation. Then verify suspend and a deliberate hibernate/resume while
on AC power with work saved. Re-run a real backup/restore after updating paths.
Do not enable critical-battery Hibernate on an unverified resume setup; select a
safe emergency power policy until resume is verified.

Retain the original verified backup and recovery media until these tests pass.
Re-encrypting current storage does not revoke plaintext/older encrypted copies
in snapshots or backups: rotate credentials where historical exposure matters.
The backup key and Restic password also need protected recovery copies once
storage encryption is in place; full-disk encryption protects at rest, not from
a compromised running UID or root.
