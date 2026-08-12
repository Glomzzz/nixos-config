#!/usr/bin/env fish

while not sudo nixos-rebuild switch --flake path:.
    sleep 3
end
