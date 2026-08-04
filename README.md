# NixOS Configuration

This repository contains my NixOS configuration files.

Based on Flakes & Home Manager

## Develop Dev Env...

Keep language toolchains out of the global NixOS configuration. Each project
should define its compiler, native dependencies, and development tools in a
local `flake.nix`, then commit the generated `flake.lock`. This keeps the
command-line environment, editor, and CI on the same toolchain.

Add the following `.envrc` to either kind of project to enter its development
shell automatically:

```bash
use flake
```

Run `direnv allow` once after creating or changing it.

### OCaml

For most OCaml projects, use Nix for OCaml and development tools, and use Dune
for builds. A minimal `flake.nix` is:

```nix
{
  description = "OCaml development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {nixpkgs, ...}: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
    ocamlPkgs = pkgs.ocamlPackages;
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = [
        ocamlPkgs.ocaml
        ocamlPkgs.dune_3
        ocamlPkgs.ocaml-lsp
        ocamlPkgs.ocamlformat
        ocamlPkgs.utop
        pkgs.pkg-config
      ];
    };
  };
}
```

Enter the environment and create or build the project with:

```bash
nix develop
dune init project my_project
cd my_project
dune build
dune test
```

Use `pkgs.ocamlPackages` for straightforward Nix-native projects. For an
existing project with `.opam` files, or when exact opam dependency resolution
is important, use [`opam-nix`](https://github.com/tweag/opam-nix). Plain opam
inside a Nix shell is useful for experimentation, but splits dependency state
between Nix and opam and is less reproducible.

### Haskell

For most Haskell projects, use Nix for GHC, native libraries, and development
tools, and use Cabal for Haskell dependencies and builds. Keep GHC and HLS in
the same package set so their versions remain compatible:

```nix
{
  description = "Haskell development environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {nixpkgs, ...}: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
    hs = pkgs.haskellPackages;
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = [
        hs.ghc
        hs.cabal-install
        hs.haskell-language-server
        hs.fourmolu
        hs.hlint
        pkgs.pkg-config
      ];
    };
  };
}
```

Enter the environment and create or build the project with:

```bash
nix develop
cabal update
cabal init
cabal build all
cabal test all
```

Add native libraries such as `zlib`, `openssl`, or PostgreSQL to the shell only
when the project needs them. For applications, pin the Hackage `index-state`
and commit `cabal.project.freeze`; libraries should generally test supported
dependency ranges instead of enforcing one frozen plan.

Use `callCabal2nix` for straightforward reproducible Nix builds. Use
[`haskell.nix`](https://github.com/input-output-hk/haskell.nix) when a large or
multi-package project needs exact Cabal plans, cross-compilation, or more
control over production builds. Avoid `ghcup` on NixOS unless it is explicitly
required, because its prebuilt tools expect a conventional Linux filesystem.
When using Stack, configure it to use the GHC supplied by Nix rather than
downloading another compiler.

## Configuration history

- 24.12.4, Basic configuration for my laptop. (0c6678)
  - Based on Flake & HomeManager
  - Hardware drivers, nessessary packages.
    - NVIDIA, Intel, WiFi, Bluetooth, etc.
  - Without development tools, i'm ganna get 'em.
- 24.12.4, Shell environment configuration. (533e662)
  - Alacritty + Starship + Nushell
- 24.12.5, KDE panels config in plasma-manager (but doesn't work currently)
- 24.12.6, Nushell full completions, via nu-scripts/completions in nixpkgs
  - Also direnv works now. 
- 24.12.7, qq and wechat-uos works well now.  
  - Except for some issues about fcitx5 (fixed in 25.5.19-9ccac7d)
    - when wechat is lauched the fcitx5 muse be relauched to work in wechat-uos 
- 25.5.12, nvidia-driver (unfree,beta) works fine now (9cd2df)
  - the problem is about power-management:
    - power management is required to get nvidia GPUs to behave on suspend, due to firmware bugs.
    - ***Aren't nvidia great?***
  - so please turn off it.
- 25.5.13, Steam works well (e30354)
  - Enjoy DOTA2 on NixOS~
- 25.5.14, [nixvim](https://github.com/Glomzzz/nixvim) works well (378a3c)
  - All stuff got reproducibility
  - ***Aren't Nix great?***
- 25.5.19, embrace home-manager 25.05 & NixOS 25.11 (9ccac7d)
  - Enabled Fcitx5 wayland-frontend to fix inputmethod problem in wechat-uos
- 26.3.20, refactor file structure for better module split (9cc1a4a)
  - Hosts/Systems/Services
