# Common commands for the NixOS configuration.

deploy:
  sudo nixos-rebuild switch --flake .

build HOST="nixos":
  host='{{HOST}}'; host="${host#HOST=}"; nix build ".#nixosConfigurations.${host}.config.system.build.toplevel" --no-link

check:
  nix flake check --no-build

# Format every .nix file in place with alejandra (the flake's formatter).
format:
  nix fmt -- .

format-check:
  nix fmt -- --check .

# Everything CI enforces: formatting, dead code, lints, and a full eval.
lint:
  nix build --no-link \
    '.#checks.x86_64-linux.formatting' \
    '.#checks.x86_64-linux.dead-code' \
    '.#checks.x86_64-linux.lint'

# Build the deepseek-harness package alone (fast iteration on its derivation
# or bundled plugins). --cores 2 keeps the npm dependency fetcher's parallel
# downloads below the registry's connection-reset threshold.
dsh:
  nix build ".#nixosConfigurations.nixos.pkgs.deepseek-harness" --no-link --cores 2

debug:
  sudo nixos-rebuild switch --flake . --show-trace --verbose

update:
  nix flake update

upgrade NAME:
  name='{{NAME}}'; name="${name#NAME=}"; nix flake update "$name"

history:
  sudo nix profile history --profile /nix/var/nix/profiles/system

repl:
  nix repl -f flake:nixpkgs

clean:
  sudo nix profile wipe-history --profile /nix/var/nix/profiles/system --older-than 7d

clean-backups:
  find ~/.config -name "*.hm-backup*" -type f -delete 2>/dev/null || true
  find ~ -maxdepth 1 -name ".*.hm-backup*" -type f -delete 2>/dev/null || true

gc:
  sudo nix store gc --debug
  sudo nix-collect-garbage --delete-old
