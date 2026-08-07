{lib, ...}: {
  services.speechd.enable = lib.mkForce false;
}
