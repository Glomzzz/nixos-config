#!/usr/bin/env fish

while not ./scripts/with-github-token sudo --preserve-env=NIX_CONFIG nixos-rebuild switch --flake path:.
    sleep 3
end
