# Common commands for the NixOS configuration.
#
# Every recipe that evaluates the host uses --impure: hardware/default.nix reads
# DMI data from /sys to choose the hardware profile.

gh := "./scripts/with-github-token"

# Non-CN fetches (cache.nixos.org, flake inputs, source tarballs) go through the local
# mihomo listener; CN mirrors and private ranges stay direct. Set DEPLOY_PROXY to use
# another proxy. Keep no_proxy_list in sync with modules/services/nixos/selector4nix.nix.
deploy_proxy := env_var_or_default("DEPLOY_PROXY", "http://127.0.0.1:20172")
no_proxy_list := "localhost,127.0.0.1,::1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,100.64.0.0/10,mirrors.ustc.edu.cn"
export http_proxy := deploy_proxy
export https_proxy := deploy_proxy
export HTTP_PROXY := deploy_proxy
export HTTPS_PROXY := deploy_proxy
export no_proxy := no_proxy_list
export NO_PROXY := no_proxy_list

# Build the host without changing the active system.
build HOST="nixos":
  {{gh}} nix build --impure ".#nixosConfigurations.{{HOST}}.config.system.build.toplevel" --no-link

# Apply the configuration.
deploy:
  {{gh}} sudo --preserve-env=NIX_CONFIG,http_proxy,https_proxy,HTTP_PROXY,HTTPS_PROXY,no_proxy,NO_PROXY nixos-rebuild switch --flake . --impure

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

# Scan the full git history (all refs) for credentials. Values are redacted.
scan-secrets:
  nix run nixpkgs#gitleaks -- git --redact --no-banner --log-opts=--all --exit-code 1 .

# Scan only staged changes, the same check as the pre-commit hook.
scan-staged:
  nix run nixpkgs#gitleaks -- git --redact --no-banner --staged --exit-code 1 .

# Use the versioned hooks in .githooks (run once per clone).
hooks:
  git config core.hooksPath .githooks

# Pin only after this running generation has been verified on the hardware.
pin-known-good:
  sudo nix-store --add-root /nix/var/nix/gcroots/known-good-nixos --realise "$(readlink -f /run/current-system)"
