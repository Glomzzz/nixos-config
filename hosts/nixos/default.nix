# Host entry for the nixosConfigurations: the shared host settings (shared.nix) plus
# the hardware profile selected from DMI (hardware/default.nix).
_: {
  imports = [
    ../../hardware
    ./shared.nix
  ];
}
