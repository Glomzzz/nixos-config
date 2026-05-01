{lib, ...}: {
  nix.settings.trusted-users = lib.mkForce [
    "root"
    "glom"
  ];
  imports = [
    ./sops
    ./locale.nix
    ./fonts.nix
    ./android.nix
    ./networking.nix
    ./plasma-auth.nix
    ./opencode.nix
    ./nix-ld.nix
    ./home-manager.nix
    ./input.nix
  ];
}
