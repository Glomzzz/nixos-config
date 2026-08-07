# NixOS Configuration

This is a flake-based NixOS and Home Manager configuration for the `nixos`
host and the `glom` user. The configuration is assembled from small modules so
hardware, system features, services, and user programs have clear ownership.

## Layout

```text
hosts/nixos/             host composition and machine-wide overrides
hardware/zephyrus/       Zephyrus-specific boot, disk, GPU, and peripherals
modules/nixos/core/      baseline NixOS settings
modules/nixos/desktop/   display manager and Plasma settings
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

## Development tools

General editors, shells, language toolchains, and command-line utilities are
installed through Home Manager under `modules/home/programs/`. Project-specific
dependencies should stay in the project's own flake or development shell so
they remain reproducible and do not enlarge the base system.
