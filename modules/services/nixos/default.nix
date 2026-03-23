{lib, ...}: {
  imports = [
    ../../../system/ollama.nix
    ../../../system/sub2api.nix
    ../../../system/clamav.nix
  ];

  services.speechd.enable = lib.mkForce false;
}
