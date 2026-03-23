# Coherence Audit Matrix

This matrix covers the repository's Nix config files under `flake.nix`, `hosts/`, `users/`, `modules/`, `home/`, `system/`, `hardware/`, and `pkgs/`.

- **Active** means reachable from `flake.nix` for `nixosConfigurations.nixos` today.
- **Disposition** is the intended final state for each file: `keep`, `rename`, `split`, `move`, or `delete`.
- Legacy `home/**` and `system/**` files are included because some are still active through wrapper imports and the rest remain coherence debt that affects the final tree audit.

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
| `modules/home/programs/browser.nix` | yes | keep | Active final entrypoint, even though it still wraps a legacy `home/**` leaf today. |
| `modules/home/programs/git.nix` | yes | keep | Active final entrypoint, still wrapping a legacy `home/**` leaf. |
| `modules/home/programs/xdg.nix` | yes | keep | Active final entrypoint, still wrapping a legacy `home/**` leaf. |
| `modules/home/programs/code.nix` | yes | keep | Active final entrypoint, still wrapping a legacy `home/**` leaf. |
| `modules/home/programs/util.nix` | yes | keep | Active final entrypoint, still wrapping a legacy `home/**` leaf. |
| `modules/home/programs/nixvim.nix` | yes | keep | Active final entrypoint, still wrapping a legacy `home/**` leaf. |
| `modules/home/shell/default.nix` | yes | keep | Active shell/session aggregator. |
| `modules/home/shell/alacritty.nix` | yes | keep | Active final entrypoint, still wrapping a legacy `home/**` leaf. |
| `modules/home/shell/nushell.nix` | yes | keep | Active final entrypoint, still wrapping a legacy `home/**` leaf. |
| `modules/home/shell/terminal-tools.nix` | yes | keep | Live terminal helper module. |
| `modules/home/shell/starship.nix` | yes | keep | Active final entrypoint, still wrapping a legacy `home/**` leaf. |
| `modules/home/shell/ssh.nix` | yes | keep | Live Home Manager SSH config module. |
| `modules/home/desktop/default.nix` | yes | keep | Active desktop aggregator. |
| `modules/home/desktop/fcitx5.nix` | yes | keep | Active final entrypoint, still wrapping a legacy `home/**` leaf. |
| `modules/home/desktop/plasma.nix` | yes | keep | Active final entrypoint, still wrapping a legacy `home/**` leaf. |
| `modules/services/home/default.nix` | yes | keep | Active Home Manager services aggregator. |
| `modules/services/home/playerctld.nix` | yes | keep | Active player control service module. |
| `modules/services/home/syncthing.nix` | yes | keep | Active Syncthing service module. |
| `modules/services/home/udiskie.nix` | yes | keep | Active Udiskie service module. |
| `modules/services/default.nix` | no | delete | Unused umbrella root; the active graph imports `modules/services/home` and `modules/services/nixos` directly. |

## Legacy `home/` tree

| Path | Active | Disposition | Rationale |
| --- | --- | --- | --- |
| `home/programs/browser.nix` | yes | move | Still active through `modules/home/programs/browser.nix`; contents belong at the module entrypoint level, not in the legacy top-level `home/` tree. |
| `home/programs/google-chrome-beta.nix` | yes | move | Still active through `home/programs/browser.nix`; should live beside the final browser module structure rather than under legacy `home/`. |
| `home/programs/git.nix` | yes | move | Still active through `modules/home/programs/git.nix`; final home tree should not depend on top-level legacy `home/`. |
| `home/programs/xdg.nix` | yes | move | Still active through `modules/home/programs/xdg.nix`; should be folded into the final module tree. |
| `home/programs/code.nix` | yes | move | Still active through `modules/home/programs/code.nix`; content belongs under the final `modules/home/programs` tree. |
| `home/programs/util.nix` | yes | move | Still active through `modules/home/programs/util.nix`; tool definitions should be migrated into the final module tree. |
| `home/nixvim/default.nix` | yes | move | Still active through `modules/home/programs/nixvim.nix`; final location should be under `modules/home`. |
| `home/plasma/default.nix` | yes | move | Still active through `modules/home/desktop/plasma.nix`; final desktop config belongs under `modules/home/desktop`. |
| `home/fcitx5/default.nix` | yes | move | Still active through `modules/home/desktop/fcitx5.nix`; final desktop config belongs under `modules/home/desktop`. |
| `home/shell/alacritty/default.nix` | yes | move | Still active through `modules/home/shell/alacritty.nix`; final shell config belongs under `modules/home/shell`. |
| `home/shell/nushell/default.nix` | yes | move | Still active through `modules/home/shell/nushell.nix`; final shell config belongs under `modules/home/shell`. |
| `home/shell/nushell/nu_scripts.nix` | yes | move | Active leaf under the legacy Nushell subtree; should move with the final Nushell module content. |
| `home/shell/starship.nix` | yes | move | Still active through `modules/home/shell/starship.nix`; final shell config belongs under `modules/home/shell`. |
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
- The active Home Manager graph is mostly coherent under `modules/home/**`, but several wrapper entrypoints still import legacy `home/**` leaves; the matrix records both sides explicitly so the final tree claim stays honest.
- The legacy `system/**` tree is not active in the current host graph and remains cleanup debt only.
