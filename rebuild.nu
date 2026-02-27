#!/usr/bin/env nu

loop {
    try {
        sudo nixos-rebuild switch --flake .
        break
    } catch {
        sleep 3sec
    }
}
