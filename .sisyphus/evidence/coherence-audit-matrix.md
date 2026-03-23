# Coherence Audit Matrix

This matrix covers the repository's Nix config files under `flake.nix`, `hosts/`, `users/`, `modules/`, `home/`, `system/`, `hardware/`, and `pkgs/`.

- **Active** means reachable from `flake.nix` for `nixosConfigurations.nixos` today.
- **Disposition** is the intended final state for each file: `keep`, `rename`, `split`, `move`, or `delete`.
- Legacy `home/**` and `system/**` files are included to record remaining inactive cleanup debt and preserve a truthful final-tree audit.

## Root + host graph

| Path | Active | Disposition | Rationale |
| --- | --- | --- | --- |
| `flake.nix` | yes | keep | Root entrypoint; now exposes the formatter, lint checks, and host check. |
| `hosts/nixos/default.nix` | yes | keep | Canonical host assembly point for the `nixos` machine. |
| `hosts/nixos/networking.nix` | yes | keep | Host-local networking override imported by the host root. |
| `users/glom/default.nix` | yes | keep | Active user-scoped NixOS settings. |
| `users/glom/home.nix` | yes | keep | Active Home Manager user entrypoint consumed by `modules/nixos/core/home-manager.nix`. |
| `users/glom/ssh/authorizedKeys.nix` | yes | keep | Active SSH key source imported by `modules/services/nixos/openssh.nix`. |

## Hardware tree

| Path | Active | Disposition | Rationale |
| --- | --- | --- | --- |
| `hardware/zephyrus/default.nix` | yes | keep | Host hardware root imported directly by `hosts/nixos/default.nix`. |
| `hardware/zephyrus/asus.nix` | yes | keep | Live Zephyrus hardware leaf imported by the hardware root. |
| `hardware/zephyrus/audio.nix` | yes | keep | Live audio hardware config for the host. |
| `hardware/zephyrus/bluetooth.nix` | yes | keep | Live Bluetooth hardware config for the host. |
| `hardware/zephyrus/boot.nix` | yes | keep | Live boot hardware config for the host. |
| `hardware/zephyrus/disk.nix` | yes | keep | Live disk layout config for the host. |
| `hardware/zephyrus/graphics-stack.nix` | yes | keep | Final host-local graphics stack module replacing the old broad graphics bucket. |
| `hardware/zephyrus/gpu/default.nix` | yes | keep | Live GPU-specific hardware module. |
| `hardware/zephyrus/cpu/default.nix` | yes | keep | Live CPU-specific hardware module. |

## Active modules tree

| Path | Active | Disposition | Rationale |
| --- | --- | --- | --- |
| `modules/nixos/default.nix` | yes | keep | Active NixOS module root. |
| `modules/nixos/core/default.nix` | yes | keep | Active core NixOS aggregator. |
| `modules/nixos/core/nix.nix` | yes | keep | Live core Nix configuration. |
| `modules/nixos/core/locale.nix` | yes | keep | Live locale configuration. |
| `modules/nixos/core/fonts.nix` | yes | keep | Live fonts configuration. |
| `modules/nixos/core/networking.nix` | yes | keep | Shared networking defaults still in active host graph. |
| `modules/nixos/core/plasma-auth.nix` | yes | keep | Active shared Plasma auth config. |
| `modules/nixos/core/sops.nix` | yes | keep | Active secrets/SOPS configuration. |
| `modules/nixos/core/home-manager.nix` | yes | keep | Active bridge from NixOS to Home Manager user config. |
| `modules/nixos/programs/default.nix` | yes | keep | Active NixOS programs aggregator. |
| `modules/nixos/programs/system-tools.nix` | yes | keep | Final shared system-tools module replacing the old `system/programs.nix` bucket. |
| `modules/nixos/programs/nix-ld.nix` | yes | keep | Active nix-ld program module. |
| `modules/nixos/programs/steam.nix` | yes | keep | Active Steam module. |
| `modules/services/nixos/default.nix` | yes | keep | Active NixOS services aggregator. |
| `modules/services/nixos/clamav.nix` | yes | keep | Active ClamAV service module. |
| `modules/services/nixos/ollama.nix` | yes | keep | Active Ollama service module. |
| `modules/services/nixos/openssh.nix` | yes | keep | Active OpenSSH service module wired to the user key source. |
| `modules/services/nixos/printing.nix` | yes | keep | Active printing service module. |
| `modules/services/nixos/sub2api.nix` | yes | keep | Active service module for the custom `sub2api` package. |
| `modules/services/nixos/tailscale.nix` | yes | keep | Active Tailscale service module. |
| `modules/home/default.nix` | yes | keep | Active Home Manager module root. |
| `modules/home/programs/default.nix` | yes | keep | Active Home Manager programs aggregator. |
| `modules/home/programs/dev/default.nix` | yes | keep | Active dev-programs aggregator. |
| `modules/home/programs/dev/cpp.nix` | yes | keep | Live C/C++ development module. |
| `modules/home/programs/dev/graphics-debug.nix` | yes | keep | Live graphics-debug module after hardware split. |
| `modules/home/programs/dev/java.nix` | yes | keep | Live Java development module. |
| `modules/home/programs/dev/other.nix` | yes | keep | Live miscellaneous dev-tooling module. |
| `modules/home/programs/dev/rust.nix` | yes | keep | Live Rust development module. |
| `modules/home/programs/cli-tools.nix` | yes | keep | Live CLI tooling module. |
| `modules/home/programs/dev-cli.nix` | yes | keep | Live developer CLI tooling module. |
| `modules/home/programs/communication.nix` | yes | keep | Live communication apps module. |
| `modules/home/programs/network-clients.nix` | yes | keep | Live network client apps module. |
| `modules/home/programs/documents.nix` | yes | keep | Live document tooling module. |
| `modules/home/programs/gaming-utils.nix` | yes | keep | Live gaming utility module. |
| `modules/home/programs/gaming-wine.nix` | yes | keep | Live Wine-facing Home Manager module. |
| `modules/home/programs/system-utilities.nix` | yes | keep | Live system-utility Home Manager module. |
| `modules/home/programs/productivity.nix` | yes | keep | Live productivity apps module. |
| `modules/home/programs/creative.nix` | yes | keep | Live creative apps module. |
| `modules/home/programs/gaming.nix` | yes | keep | Live gaming apps module. |
| `modules/home/programs/browser.nix` | yes | keep | Active final browser entrypoint; now sources only module-local assets. |
| `modules/home/programs/google-chrome-beta.nix` | yes | keep | Active browser package leaf moved under the final `modules/home/programs` tree. |
| `modules/home/programs/git.nix` | yes | keep | Active final git entrypoint with no legacy `home/**` dependency. |
| `modules/home/programs/xdg.nix` | yes | keep | Active final XDG entrypoint with no legacy `home/**` dependency. |
| `modules/home/programs/code.nix` | yes | keep | Active final code entrypoint with no legacy `home/**` dependency. |
| `modules/home/programs/util.nix` | yes | keep | Active final utility entrypoint with no legacy `home/**` dependency. |
| `modules/home/programs/nixvim.nix` | yes | keep | Active final Nixvim entrypoint with no legacy `home/**` dependency. |
| `modules/home/shell/default.nix` | yes | keep | Active shell/session aggregator. |
| `modules/home/shell/alacritty.nix` | yes | keep | Active final Alacritty entrypoint; now imports only module-local theme assets. |
| `modules/home/shell/alacritty/catppuccin-mocha.toml` | yes | keep | Active Alacritty theme asset moved under the final `modules/home/shell` tree. |
| `modules/home/shell/nushell.nix` | yes | keep | Active final Nushell entrypoint with no legacy `home/**` dependency. |
| `modules/home/shell/terminal-tools.nix` | yes | keep | Live terminal helper module. |
| `modules/home/shell/starship.nix` | yes | keep | Active final Starship entrypoint with no legacy `home/**` dependency. |
| `modules/home/shell/ssh.nix` | yes | keep | Live Home Manager SSH config module. |
| `modules/home/desktop/default.nix` | yes | keep | Active desktop aggregator. |
| `modules/home/desktop/fcitx5.nix` | yes | keep | Active final Fcitx5 entrypoint with no legacy `home/**` dependency. |
| `modules/home/desktop/plasma.nix` | yes | keep | Active final Plasma entrypoint with no legacy `home/**` dependency. |
| `modules/services/home/default.nix` | yes | keep | Active Home Manager services aggregator. |
| `modules/services/home/playerctld.nix` | yes | keep | Active player control service module. |
| `modules/services/home/syncthing.nix` | yes | keep | Active Syncthing service module. |
| `modules/services/home/udiskie.nix` | yes | keep | Active Udiskie service module. |
| `modules/services/default.nix` | no | delete | Unused umbrella root; the active graph imports `modules/services/home` and `modules/services/nixos` directly. |

## Legacy `home/` tree

| Path | Active | Disposition | Rationale |
| --- | --- | --- | --- |
| `home/programs/browser.nix` | no | move | Inactive legacy browser module retained only as cleanup debt after the browser entrypoint was made self-contained under `modules/home/programs`. |
| `home/programs/google-chrome-beta.nix` | no | move | Inactive legacy browser package leaf superseded by `modules/home/programs/google-chrome-beta.nix`. |
| `home/programs/git.nix` | no | move | Inactive legacy git module superseded by the final `modules/home/programs/git.nix` entrypoint. |
| `home/programs/xdg.nix` | no | move | Inactive legacy XDG module superseded by the final `modules/home/programs/xdg.nix` entrypoint. |
| `home/programs/code.nix` | no | move | Inactive legacy code module superseded by the final `modules/home/programs/code.nix` entrypoint. |
| `home/programs/util.nix` | no | move | Inactive legacy utility module superseded by the final `modules/home/programs/util.nix` entrypoint. |
| `home/nixvim/default.nix` | no | move | Inactive legacy Nixvim module superseded by the final `modules/home/programs/nixvim.nix` entrypoint. |
| `home/plasma/default.nix` | no | move | Inactive legacy Plasma module superseded by `modules/home/desktop/plasma.nix`. |
| `home/fcitx5/default.nix` | no | move | Inactive legacy Fcitx5 module superseded by `modules/home/desktop/fcitx5.nix`. |
| `home/shell/alacritty/default.nix` | no | move | Inactive legacy Alacritty module superseded by `modules/home/shell/alacritty.nix`. |
| `home/shell/alacritty/catppuccin-mocha.toml` | no | move | Inactive legacy Alacritty theme asset superseded by `modules/home/shell/alacritty/catppuccin-mocha.toml`. |
| `home/shell/nushell/default.nix` | no | move | Inactive legacy Nushell module superseded by `modules/home/shell/nushell.nix`. |
| `home/shell/nushell/nu_scripts.nix` | no | move | Inactive legacy Nushell helper leaf now outside the active Home Manager graph. |
| `home/shell/starship.nix` | no | move | Inactive legacy Starship module superseded by `modules/home/shell/starship.nix`. |
| `home/programs/media.nix` | no | split | Inactive broad bucket that still mixes packages, `programs.mpv`, and player services. |
| `home/shell/default.nix` | no | delete | Inactive broad bucket superseded by `modules/home/shell/default.nix`. |

## Legacy `system/` tree

| Path | Active | Disposition | Rationale |
| --- | --- | --- | --- |
| `system/programs.nix` | no | split | Inactive legacy catch-all replaced by focused NixOS program modules such as `modules/nixos/programs/system-tools.nix`. |
| `system/wine.nix` | no | split | Inactive legacy mixed Wine bucket; the final graph keeps Wine-related user tooling under focused modules. |
| `system/env/default.nix` | no | delete | Inactive legacy env umbrella superseded by focused development modules. |
| `system/env/cpp.nix` | no | move | Inactive legacy C/C++ env content belongs under `modules/home/programs/dev/cpp.nix`. |
| `system/env/java.nix` | no | move | Inactive legacy Java env content belongs under `modules/home/programs/dev/java.nix`. |
| `system/env/rust.nix` | no | move | Inactive legacy Rust env content belongs under `modules/home/programs/dev/rust.nix`. |
| `system/env/other.nix` | no | move | Inactive legacy miscellaneous env content belongs under `modules/home/programs/dev/other.nix`. |

## `pkgs/` tree

| Path | Active | Disposition | Rationale |
| --- | --- | --- | --- |
| `pkgs/codex.nix` | yes | keep | Active overlay package exported in `hosts/nixos/default.nix`. |
| `pkgs/sub2api.nix` | yes | keep | Active overlay package consumed by `modules/services/nixos/sub2api.nix`; known legacy `system` warning remains expected. |
| `pkgs/tracy/package.nix` | yes | keep | Active custom package called from `home/programs/util.nix`. |
| `pkgs/tracy/package-versions.nix` | yes | keep | Active support file imported by `pkgs/tracy/package.nix`. |
| `pkgs/tracy/tracy-0.13.nix` | yes | keep | Active version source for `tracy_latest`. |
| `pkgs/tracy/tracy-0.12.nix` | no | keep | Inactive alternate version retained intentionally by `package-versions.nix` for package history/version selection. |
| `pkgs/tracy/tracy-0.11.nix` | no | keep | Inactive alternate version retained intentionally by `package-versions.nix` for package history/version selection. |

## Final audit conclusions

- The active NixOS host graph is rooted in `flake.nix`, `hosts/nixos/default.nix`, `hardware/zephyrus/default.nix`, `modules/nixos/default.nix`, `users/glom/default.nix`, and `users/glom/home.nix`.
- The active Home Manager graph is now self-contained under `modules/home/**`; the remaining `home/**` entries recorded here are inactive cleanup debt, not active dependencies.
- The legacy `system/**` tree is not active in the current host graph and remains cleanup debt only.
