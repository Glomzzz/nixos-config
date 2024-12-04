{
  description = "Glom's Flake configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/";
    helix.url = "github:helix-editor/helix/master";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    catppuccin-bat = {
      url = "github:catppuccin/bat";
      flake = false;
    };
  };

  outputs = inputs@{ nixpkgs, home-manager, ... }: {
    nixosConfigurations = {
      nixos = 
        let 
            hostname = "nixos";
            username = "glom";
            specialArgs = {inherit hostname; inherit username;};
        in nixpkgs.lib.nixosSystem {
            inherit specialArgs;
            system = "x86_64-linux";
            modules = [
              ./hosts/nixos
              ./users/${username}
              home-manager.nixosModules.home-manager {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;

                home-manager.users.glom = import ./users/${username}/home.nix;
                home-manager.extraSpecialArgs = inputs // {inherit username;};
              }
            ];
          };
    };
  };
}