# just is a command runner, Justfile is very similar to Makefile, but simpler.

deploy:
  sudo nixos-rebuild switch --flake . --sudo

build HOST='nixos':
  host='{{HOST}}'; host="${host#HOST=}"; nix build ".#nixosConfigurations.${host}.config.system.build.toplevel" --no-link

check:
  nix flake check --no-build

############################################################################
#
#  Nix commands related to the local machine
#
############################################################################


debug:
  sudo nixos-rebuild switch --flake . --sudo --show-trace --verbose

update:
  sudo nix flake update

# Update specific input
# usage: make upp i=home-manager
upgrade NAME:
  sudo nix flake update {{NAME}}

history:
  sudo nix profile history --profile /nix/var/nix/profiles/system

repl:
  sudo nix repl -f flake:nixpkgs

clean:
  # remove all generations older than 7 days
  sudo nix profile wipe-history --profile /nix/var/nix/profiles/system  --older-than 7d

# Clean up home-manager backup files that cause rebuild failures
clean-backups:
  find ~/.config -name "*.hm-backup*" -type f -delete 2>/dev/null || true
  find ~ -maxdepth 1 -name ".*.hm-backup*" -type f -delete 2>/dev/null || true
  echo "Cleaned up hm-backup files"

gc:
  # garbage collect all unused nix store entries
  sudo nix store gc --debug
  sudo nix-collect-garbage --delete-old

# why:
#   nix shell nixpkgs#nix-tree nixpkgs#ripgrep
#   nix-store --gc --print-roots | rg -v '/proc/' | rg -Po '(?<= -> ).*' | xargs -o nix-tree
