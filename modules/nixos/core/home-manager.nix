{
  inputs,
  specialArgs,
  ...
}: {
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.glom = import ../../../users/glom/home.nix;
  home-manager.extraSpecialArgs = inputs // specialArgs;
}
