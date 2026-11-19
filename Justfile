# Common commands for the NixOS configuration.
#
# Every recipe that evaluates the host uses --impure: hardware/default.nix reads
# DMI data from /sys to choose the hardware profile.

gh := "./scripts/with-github-token"

# Build the host without changing the active system.
build HOST="nixos":
  {{gh}} nix build --impure ".#nixosConfigurations.{{HOST}}.config.system.build.toplevel" --no-link

# Apply the configuration.
deploy:
  {{gh}} sudo --preserve-env=NIX_CONFIG nixos-rebuild switch --flake . --impure

# Format every .nix file in place with alejandra (the flake's formatter).
format:
  {{gh}} nix fmt -- .

# Update all inputs, or one input: `just upgrade nixpkgs`.
update:
  {{gh}} nix flake update

upgrade NAME:
  {{gh}} nix flake update {{NAME}}

history:
  sudo nix profile history --profile /nix/var/nix/profiles/system

repl:
  {{gh}} nix repl -f flake:nixpkgs

clean:
  sudo nix profile wipe-history --profile /nix/var/nix/profiles/system --older-than 30d

gc:
  sudo nix-collect-garbage --delete-older-than 30d

# Pin only after this running generation has been verified on the hardware.
pin-known-good:
  sudo nix-store --add-root /nix/var/nix/gcroots/known-good-nixos --realise "$(readlink -f /run/current-system)"
