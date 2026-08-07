# Common commands for the NixOS configuration.

deploy:
  sudo nixos-rebuild switch --flake .

build HOST="nixos":
  host='{{HOST}}'; host="${host#HOST=}"; nix build ".#nixosConfigurations.${host}.config.system.build.toplevel" --no-link

check:
  nix flake check --no-build

format-check:
  nix fmt -- --check .

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
