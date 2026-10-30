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
scripts/                 manual rebuild and proxy helpers
```

`flake.nix` composes the host. `hosts/nixos/default.nix` imports the hardware
profile, shared NixOS modules, the user module, and generated Cachix settings.
The Home Manager bridge in `modules/nixos/core/home-manager.nix` loads the
user's Home Manager entrypoint.

## Common commands

```bash
# Evaluate every flake output (does not execute tests)
just eval

# Execute regression checks without building the full system
just test

# Build without changing the active system
just build

# Evaluate, lint, execute tests, and build the full system
just validate

# Check formatting separately
just format-check

# Update inputs (or one input with `just upgrade NAME=...`)
just update

# Apply the configuration
just deploy
```

`just check` remains an alias for evaluation only. `just lint` runs formatting,
dead-code, and Nix-lint checks; `just test` dynamically discovers all remaining
checks except the full host build. Checks are defined in `checks/default.nix`.
Use `nix fmt -- .` to format Nix files. Neither tests nor a build switch
generations; use `deploy` only when the generated system has been reviewed.

The scripts under `scripts/` are manual recovery helpers, not part of the
declarative configuration. Review them before running because they use `sudo`
and can restart system services.

## Secrets

Encrypted SOPS files and evaluation-time personal metadata live in the private
`Glomzzz/nixos-secrets` flake. The public configuration consumes that flake but
never contains its source files. Machine secrets use OpenPGP operator access and
unattended host-age decryption. The separately enrolled YubiKey user PIN is a
host-age-only convenience exception: the laptop can recover it without the key,
so it removes independent PIN protection while retaining card touch checks.
User credentials use only the YubiKey-backed OpenPGP identity;
`user-credentials` explicitly unlocks them for a command or SMB connection. No
API tokens are automatically exported into shells. See [secret management](docs/secrets.md)
for commands and migration limits. Never add plaintext API keys, passwords,
private keys, or PINs to Nix files.

Commands that evaluate this flake need a GitHub token for the private input. Use
`just check`, `just build`, or `just deploy`; they obtain the token through `gh`
and pass it ephemerally via `NIX_CONFIG`. Do not put a token in `flake.nix` or a
committed environment file.

## Recovery generations

GC runs weekly and retains generations from the last 30 days. Before enabling
the new policy, use `just pin-known-good` on a verified running system to preserve
its store closure independently of age-based pruning. See
[recovery instructions](docs/recovery.md). Automatic hourly and boot-time Btrfs
snapshots are disabled after a metadata-full incident. Snapper remains available
for manual recovery, with daily cleanup of existing snapshots. These local
snapshots do not protect against disk failure or theft; off-device backups remain
to be configured.

## Authentication

TTY1 shows a wallpaper-backed, dark ReGreet login screen with a clock and
user/session selection. Password authentication starts Niri and unlocks GNOME
Keyring; other VTs remain recovery shells. Sudo accepts a successful Howdy face
match without a password, with password fallback if recognition fails. Screen
unlocking accepts **either Howdy or the password**: press Enter with no input to
try your face, or type the account password and press Enter. Camera failure never
blocks a valid password.
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

## Terminal Emacs

Kitty is the default terminal, with explicit Latin/CJK/emoji/icon fonts and
Emacs-friendly keyboard shortcuts. Emacs editor commands and desktop launchers
use a TTY by default; `emc -c` or **Emacs (GUI)** requests a graphical frame.
Foot remains available as a fallback.
See [terminal Emacs](docs/terminal-emacs.md) for mouse/clipboard integration,
optional image/PDF support, reserved terminal shortcuts, and GUI limitations.

## Waybar

`modules/home/desktop/niri/waybar.nix` is a small entrypoint. Its sibling
`waybar/` directory owns Nix settings, GTK CSS, the XML menu, shell helpers, and
offline tests. Run `nix build --no-link .#checks.x86_64-linux.waybar`; see the
[Waybar layout](modules/home/desktop/niri/waybar/README.md).

## Media playback

Celluloid is the graphical audio/video player and owns the media file defaults.
It embeds libmpv rather than installing a second standalone player. Its generated
`~/.config/celluloid/mpv.conf` retains safe hardware decoding, the high-quality
profile, and keep-open behavior. The old standalone `vo=gpu-next` and Vulkan
options are not carried over: Celluloid manages its embedded GTK render context.
MPRIS remains enabled for media keys and Waybar through playerctld.

Run `nix build --no-link .#checks.x86_64-linux.celluloid` to check the desktop/MIME
integration, GSettings schema, and config loading with the real libmpv. Rendering
and hardware decoding still need a playback test after activation.

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

## Desktop Chinese input

Fcitx5 is started once by Home Manager's `fcitx5-daemon.service`; the
package's XDG autostart entry is masked and niri does not spawn another daemon.
Foot uses native Wayland text-input-v3. GTK3/4 apps, including PGTK Emacs, also
use text-input-v3 rather than the Fcitx GTK plugin, whose client-side popup can
flicker when repositioning. `GTK_IM_MODULE` is intentionally unset; GTK config
files retain Fcitx for X11/GTK2 apps. Qt5 keeps `QT_IM_MODULE=fcitx`.

The Catppuccin candidate theme uses generated PNG backgrounds with solid padding
inside the border, avoiding procedural-background artifacts in bundled Qt clients
such as WeChat. WeChat stays native Wayland; no application-wide rendering or IM
backend override is needed. After deploying a theme change, restart WeChat if its
client-side candidate window still shows the old background.

**Right Shift** is the only Chinese/English toggle. Ctrl+Space, preedit toggling,
input-method group cycling, clipboard, quick phrase, Unicode entry, and keyboard
hint shortcuts are unbound so they cannot intercept Emacs commands. In particular,
**Ctrl+;** (clipboard), **Ctrl+Alt+P** (toggle preedit), and **Ctrl+.**
(punctuation toggle) are unbound. Phono uses its own candidate navigation and
Fcitx's native punctuation settings; the former Rime-specific spelling,
navigation, and punctuation overrides no longer apply.

For shortcut-only changes, `systemctl --user restart fcitx5-daemon` reloads global
and addon settings together, clearing any stale in-memory shortcut bindings.
After deploying session environment changes, log out and back in to clear the old
session environment and start the single managed daemon. Save Emacs buffers before
logging out; Home Manager deliberately does not automatically restart a running
Emacs daemon.
Check `systemctl --user status fcitx5-daemon` and confirm `printenv GTK_IM_MODULE`
prints nothing. In Foot and Emacs, press **Right Shift**, type `nihao`, and select
`你好`; check that the Emacs candidate popup stays stable while typing and near
window edges. These need interactive testing. Offline configuration regressions
run with `nix build --no-link .#checks.x86_64-linux.fcitx5`.

Phono 0.1.3 is the Chinese input engine, with Pinyin as the default and Shuangpin
also available in the managed profile. Rime and its deployment hooks are removed;
existing personal Rime data is not deleted. The phono-core 0.1.2 runtime is
packaged locally, and dictionary input works without a model. See
[Phono setup](docs/phono.md) for method selection, the separate model download,
and local inference settings.

## Dota 2 Chinese input

Keep `steam-game-laptop %command%` in Dota 2's Steam launch options (existing
arguments can follow it). For app ID 570 the launcher now uses the desktop
XWayland display instead of Gamescope, selects Fcitx and the X11 backend for
both SDL2/SDL3, and retains 2560×1600 fullscreen. Other games still use Gamescope.
Do not add another `gamescope` around Dota's command.

After deploying, reload Fcitx with `fcitx5-remote -r` and restart Dota 2. Open a
chat input, press **Right Shift**, type `nihao`, and select `你好`. No Ctrl+Space
fallback is configured. Check the modifier-only toggle, committing text, and the
candidate popup; these need an interactive in-game test, not just Nix evaluation.
Offline launcher regressions run with `nix build --no-link .#checks.x86_64-linux.steam-game-laptop`.

## Development tools

General editors, shells, language toolchains, and command-line utilities are
installed through Home Manager under `modules/home/programs/`. Project-specific
dependencies should stay in the project's own flake or development shell so
they remain reproducible and do not enlarge the base system. The base C/C++
toolchain uses wrapped GCC/Clang; Emacs's internal libgccjit is not installed as
a command-line compiler. nix-ld libraries are exposed only through its dedicated
library path, not as an extra collection of executables on the system PATH.

Docker runs rootless in `glom`'s user manager with declarative subordinate ID
ranges and lingering enabled. The account is intentionally not in the
root-equivalent `docker` group. After switching from a previous rootful Docker
setup, rootful containers and volumes under `/var/lib/docker` are not visible to
the rootless daemon; migrate or export anything needed before relying on the
new daemon. `DOCKER_HOST` is set automatically for login shells.

### Ix codebase graph

`pkgs/ix.nix` pins the official Ix release bundle, including its native parsers
and Compass UI. `modules/home/programs/dev/ix.nix` installs the CLI through Home
Manager. Node.js 22 and command-line dependencies are provided by the package;
rootless Docker is configured through the system module and the user's manager.

After deploying, start the backend explicitly and map a repository:

```bash
ix docker start
ix map /path/to/repository
ix view
```

State stays in `~/.ix` (or `$IX_HOME`). The backend is downloaded and run by
rootless Docker on first start; it is not built by Nix. No containers are
started or MCP clients modified during activation. Update the version and hash
in `pkgs/ix.nix` and rebuild rather than running `ix upgrade`, which manages a
separate, non-Nix installation. Automatic upstream update notices are disabled
by default.
