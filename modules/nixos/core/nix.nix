{lib, ...}: {
  nix.settings.trusted-users = lib.mkForce ["root" "glom"];
}
