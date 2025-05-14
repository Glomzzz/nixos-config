# NixOS Configuration

This repository contains my NixOS configuration files.

Based on Flakes & Home Manager

- 24.12.4, Basic configuration for my laptop. (0c6678c344ee88187338079f14b6bcf208b1aa3a)
  - Based on Flake & HomeManager
  - Hardware drivers, nessessary packages.
    - NVIDIA, Intel, WiFi, Bluetooth, etc.
  - Without development tools, i'm ganna get 'em.
- 24.12.4, Shell environment configuration. (533e662d1312acbc0f437c9521117ac22e8edfe3)
  - Alacritty + Starship + Nushell
- 24.12.5, KDE panels config in plasma-manager (but doesn't work currently)
- 24.12.6, Nushell full completions, via nu-scripts/completions in nixpkgs
  - Also direnv works now. 
- 24.12.7, qq and wechat-uos works well now.  
  - Except for some issues about fcitx5
    - when wechat is lauched the fcitx5 muse be relauched to work in wechat-uos
- 25.5.12, nvidia-driver (unfree,beta) works fine now (9cd2df1675155f8bd19415f04171eb514fb00656)
  - the problem is about power-management:
    - power management is required to get nvidia GPUs to behave on suspend, due to firmware bugs.
    - ***Aren't nvidia great?***
  - so please turn off it.
- 25.5.13, Steam works well (e303546d732466685f556584c159e4eb5f16cba4)
  - Enjoy DOTA2 on NixOS~
- 25.5.14, [nixvim](https://github.com/Glomzzz/nixvim) works well (378a3cc43ad1f05c79c2c70924441df03d806846)
  - All stuff got reproducibility
  - ***Aren't Nix great?***
