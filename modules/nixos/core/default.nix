{lib, ...}: {
  nix.settings.trusted-users = lib.mkForce [
    "root"
    "glom"
  ];
  imports = [
    ./sops
    ./cachix.nix
    ./locale.nix
    ./fonts.nix
    ./niri.nix
    ./android.nix
    ./ios.nix
    ./networking.nix
    ./kwallet.nix
    ./howdy.nix
    ./codex.nix
    ./opencode.nix
    ./nix-ld.nix
    ./home-manager.nix
    ./input.nix
    ./keyboard.nix
  ];
}
