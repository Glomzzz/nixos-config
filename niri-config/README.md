# Niri and Clavis Shell

This flake packages the Clavis Quickshell configuration and its native Qt
plugins, provides a Niri configuration, and exports reusable NixOS and Home
Manager modules.

The packaged desktop currently targets `x86_64-linux`.

The Clavis snapshot and its provenance are documented in `UPSTREAM.md`.
Project code is distributed under GPL-3.0-only; incorporated works retain the
licenses shipped below `quickshell/licenses/` and beside their assets.

## Development

Allow the checked-in environment once, then use the usual CMake tools inside
it:

```console
direnv allow
cmake -S quickshell/core -B quickshell/core/build -G Ninja
cmake --build quickshell/core/build
ctest --test-dir quickshell/core/build --output-on-failure
```

The flake is the source of truth for the compiler, Qt, CMake, native libraries,
QML tooling, Niri, and repository linters. Run the complete validation with:

```console
nix flake check
```

## NixOS integration

Add this repository as a flake input, import `nixosModules.default` into the
NixOS host and `homeManagerModules.default` into the user's Home Manager
configuration, then enable `services.clavis-shell` in both scopes.

The Home Manager module installs `config/niri/config.kdl` as the main Niri
configuration and starts Clavis plus its MIME-aware clipboard watcher with the
Niri systemd session. The optional `colors.kdl`, `clavis-effects.kdl`, and
`dms/cursor.kdl` files are deliberately not store-managed because Clavis
updates them at runtime.
