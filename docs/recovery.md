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
