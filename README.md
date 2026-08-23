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

## Development tools

General editors, shells, language toolchains, and command-line utilities are
installed through Home Manager under `modules/home/programs/`. Project-specific
dependencies should stay in the project's own flake or development shell so
they remain reproducible and do not enlarge the base system.

## DeepSeek Harness

The `deepseek-harness` package (`pkgs/deepseek-harness.nix`) bundles the CLI,
the web GUI, the vision/search bridges (`modlens`, `modsearch`), the routing
suite, the OpenViking MCP integration, and the terminal TUI. The first run of
each surface writes its profile under `~/.dsh/profiles/` (bundled plugins are
symlinked from the store, so no `pnpm install` or network access is needed).

- **Web GUI** — `dsh web` (serves `http://127.0.0.1:3080`); the fish helper
  `dsh-web` starts it detached with a log under `~/.local/state/dsh/` and
  opens the browser. Plugins: ModLens, ModSearch, routing suite, OpenViking.
- **TUI mode** — `dsh-tui` boots a Claude Code-style terminal front door over
  the same `dsh-base` layer (`dsh --profile dsh-tui` is equivalent). It shares
  the session store with the web GUI: `dsh-tui --resume` resumes the last
  session, `dsh-tui --resume <id>` a specific one, `-c`/`--continue` are
  aliases, and a bare positional path selects the workspace. The
  `@deepseek-harness-tui/dsh-tui` plugin is pinned in
  `pkgs/deepseek-harness/package.json` and updated through `just update` +
  rebuild, like the rest of the harness.
- **Profiles** — the web and `dsh-tui` profiles are prepared automatically by
  `pkgs/deepseek-harness/bootstrap.mjs` and re-pointed to new store paths on
  every update. Manual overrides live in each profile's `cordis.patch.yml`.
  API keys are resolved from `~/.dsh/.credentials.yaml` (the web Models page
  writes it) or the `DEEPSEEK_API_KEY`/`OPENAI_API_KEY`/`ANTHROPIC_API_KEY`
  environment variables.
- **Fish shell** — the agent's shell tool runs `fish -c` instead of `bash -c`:
  the derivation re-points the `dsh-bash-local` executor, its
  `dsh-bash-sandbox` confinement wrapper, and the `dsh-tool-bash` model-facing
  contract (see `pkgs/deepseek-harness.nix`). `fish` is resolved through the
  invoking environment's PATH, so the user's own fish stays the shell of
  record; the `--replace-fail` substitutions fail the build loudly if an
  upstream update renames them.
- **TUI rendering stability** — three local patches keep the TUI screen from
  garbling (the upstream diff engine's incremental renderer leaves stale cells
  when the layout shifts; see `patches/dsh-tui-*.patch` and issue #457
  upstream):
  - `dsh-tui-focus-loss.patch` — focus events (`CSI I`/`CSI O`, DECSET 1004)
    no longer count as "stdin resume", so blur/refocus never triggers the
    broken viewport re-anchor repaint.
  - `dsh-tui-working-line.patch` — drops the per-second working line while a
    turn is active; its drifting relative-cursor writes were the main source
    of progressive row interleaving ("chaos" on blur/scroll).
  - `dsh-tui-scrollgutter.patch` — pins `scrollGutter: hidden` in the bundled
    patch so the timeline rail cannot appear one frame after boot and rewrap
    every transcript row (stale-cell interleaving at boot).
  - `dsh-tui-inline-repaint.patch` — with `DSH_TUI_INLINE_REPAINT=1` (set on
    the `dsh-tui` wrapper) every inline frame ends by repainting the visible
    viewport from the renderer's model (the same recovery upstream enables
    for JetBrains terminals), so drifted writes can never accumulate into
    ghost rows; the screen stays clean through blur/scroll/streaming.
