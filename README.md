# NixOS Configuration

This is a flake-based NixOS and Home Manager configuration for the `nixos`
host and the `glom` user. The configuration is assembled from small modules so
hardware, system features, services, and user programs have clear ownership.

## Layout

```text
hosts/nixos/             host composition and machine-wide overrides
hardware/zephyrus/       Zephyrus-specific boot, disk, GPU, and peripherals
modules/nixos/core/      baseline NixOS settings
modules/nixos/desktop/   login manager and niri compositor settings
modules/nixos/programs/  optional system integrations and tools
modules/nixos/security/  authentication and sops-nix wiring
modules/services/nixos/  system services
modules/home/            Home Manager programs, shell, and desktop settings
modules/services/home/   Home Manager services
users/glom/              NixOS and Home Manager user entrypoints
pkgs/                    local package definitions and overlays
secrets/                 sops-encrypted host secrets
scripts/                 manual rebuild and proxy helpers
```

`flake.nix` composes the host. `hosts/nixos/default.nix` imports the hardware
profile, shared NixOS modules, the user module, and generated Cachix settings.
The Home Manager bridge in `modules/nixos/core/home-manager.nix` loads the
user's Home Manager entrypoint.

## Common commands

```bash
# Evaluate the flake and its checks
just check

# Build without changing the active system
just build

# Check formatting separately
just format-check

# Update inputs (or one input with `just upgrade NAME=...`)
just update

# Apply the configuration
just deploy
```

Use `nix fmt -- .` to format Nix files. A build does not switch generations; use
`deploy` only when the generated system has been reviewed.

The scripts under `scripts/` are manual recovery helpers, not part of the
declarative configuration. Review them before running because they use `sudo`
and can restart system services.

## Secrets

Secrets are encrypted with `sops-nix` and stored under `secrets/hosts/`. The
host's SSH host key is used for age decryption. Do not add plaintext API keys or
passwords to Nix files; add a new secret declaration under
`modules/nixos/security/sops/` and encrypt its value with `sops`.

## Recovery generations

GC runs weekly and retains generations from the last 30 days. Before enabling
the new policy, use `just pin-known-good` on a verified running system to preserve
its store closure independently of age-based pruning. See
[recovery instructions](docs/recovery.md). Snapper also takes local hourly and
boot-time Btrfs snapshots; these do not protect against disk failure or theft.
Off-device backups remain to be configured.

## Authentication

TTY1 requires the account password before Fish starts niri. Sudo accepts a
successful Howdy face match without a password, with password fallback if
recognition fails. Screen unlocking still requires both Howdy and the password.
Set the existing Login keyring's password interactively to match the account
password; see
[authentication setup and recovery](docs/authentication.md) before activating.
Disk encryption is not configured.

## Home Manager backups

When activation replaces an unmanaged file, its previous contents are moved to
`${XDG_STATE_HOME:-~/.local/state}/home-manager/backups/` in a unique timestamped
directory, preserving the path relative to your home. Rebuilds never prune these
backups or old `*.hm-backup` files. Review and restore or remove them manually.
Files declared with `force = true` bypass Home Manager's collision backups.

## Waybar

`modules/home/desktop/niri/waybar.nix` is a small entrypoint. Its sibling
`waybar/` directory owns Nix settings, GTK CSS, the XML menu, shell helpers, and
offline tests. Run `nix build --no-link .#checks.x86_64-linux.waybar`; see the
[Waybar layout](modules/home/desktop/niri/waybar/README.md).

## Clipboard

QQ and WeChat remain native Wayland applications. `clipferry` bridges their X11
clipboard access with the Wayland clipboard, including text, images, and file
URIs, even when no X11 window has focus. It runs with the graphical session in
backstop mode alongside xwayland-satellite and cliphist; password-manager-hinted
offers are excluded. PRIMARY (middle-click) is left unchanged.

After deploying, check `systemctl --user status clipferry` and
`clipferry --oneshot-check`. Test copying text and an image from Firefox or a
terminal into QQ/WeChat and back. For failures, inspect
`journalctl --user -u clipferry` (clipboard payloads are not logged).

## Dota 2 Chinese input

Keep `steam-game-laptop %command%` in Dota 2's Steam launch options (existing
arguments can follow it). For app ID 570 the launcher now uses the desktop
XWayland display instead of Gamescope, selects Fcitx and the X11 backend for
both SDL2/SDL3, and retains 2560×1600 fullscreen. Other games still use Gamescope.
Do not add another `gamescope` around Dota's command.

After deploying, reload Fcitx with `fcitx5-remote -r` and restart Dota 2. Open a
chat input, press **Ctrl+Space**, type `nihao`, and select `你好`. The existing
Shift trigger is retained. Check both committing text and the candidate popup;
these need an interactive in-game test, not just Nix evaluation. Offline launcher
regressions run with `nix build --no-link .#checks.x86_64-linux.steam-game-laptop`.

## Development tools

General editors, shells, language toolchains, and command-line utilities are
installed through Home Manager under `modules/home/programs/`. Project-specific
dependencies should stay in the project's own flake or development shell so
they remain reproducible and do not enlarge the base system.
