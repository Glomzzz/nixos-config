# Hardware-independent modules that every hardware profile imports. Exposed to
# other flakes as nixosModules.hardware-common (flake.nix).
_: {
  imports = [
    ./cpu
    ./snapshots.nix
    ./storage-health.nix
    ./bluetooth.nix
    ./audio.nix
    ./graphics-stack.nix
    ./input.nix
  ];
}
