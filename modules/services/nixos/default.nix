{lib, ...}: {
  imports = [
    ./ollama.nix
    ./openssh.nix
    ./printing.nix
    ./tailscale.nix
    # ./sub2api.nix
  ];

  services.speechd.enable = lib.mkForce false;
}
