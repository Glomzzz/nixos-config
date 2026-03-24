{lib, ...}: {
  imports = [
    ./ollama.nix
    ./openssh.nix
    ./printing.nix
    ./sub2api.nix
    ./tailscale.nix
  ];

  services.speechd.enable = lib.mkForce false;
}
