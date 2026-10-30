# Common commands for the NixOS configuration.

deploy:
  ./scripts/with-github-token sudo --preserve-env=NIX_CONFIG nixos-rebuild switch --flake .

build HOST="nixos":
  host='{{HOST}}'; host="${host#HOST=}"; ./scripts/with-github-token nix build ".#nixosConfigurations.${host}.config.system.build.toplevel" --no-link

# Evaluate every output; this does not execute build-time tests.
eval:
  ./scripts/with-github-token nix flake check --no-build --no-update-lock-file

# Compatibility alias: evaluation only. Use `test` for regression execution.
check: eval

# Run every regression check, excluding style checks and the full host build.
test:
  ./scripts/with-github-token ./scripts/test-checks

# Complete validation, including the full system build without activation.
validate: eval lint test build

# Format every .nix file in place with alejandra (the flake's formatter).
format:
  ./scripts/with-github-token nix fmt -- .

format-check:
  ./scripts/with-github-token nix fmt -- --check .

# Formatting, dead code, and Nix lints only; evaluation is a separate recipe.
lint:
  ./scripts/with-github-token nix build --no-link \
    '.#checks.x86_64-linux.formatting' \
    '.#checks.x86_64-linux.dead-code' \
    '.#checks.x86_64-linux.lint'

debug:
  ./scripts/with-github-token sudo --preserve-env=NIX_CONFIG nixos-rebuild switch --flake . --show-trace --verbose

update:
  ./scripts/with-github-token nix flake update

upgrade NAME:
  name='{{NAME}}'; name="${name#NAME=}"; ./scripts/with-github-token nix flake update "$name"

history:
  sudo nix profile history --profile /nix/var/nix/profiles/system

repl:
  ./scripts/with-github-token nix repl -f flake:nixpkgs

clean:
  sudo nix profile wipe-history --profile /nix/var/nix/profiles/system --older-than 30d

# Pin only after this running generation has been verified on the hardware.
pin-known-good:
  sudo nix-store --add-root /nix/var/nix/gcroots/known-good-nixos --realise "$(readlink -f /run/current-system)"

gc:
  sudo nix-collect-garbage --delete-older-than 30d
