{
  description = "Glom's Flake configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-alien-source.url = "github:thiagokokada/nix-alien";
  };

  outputs = inputs@{ nixpkgs, home-manager, ... }: {
    nixosConfigurations = {
      nixos = 
        let 
            system = "x86_64-linux";
            hostname = "nixos";
            username = "glom";
            specialArgs = {inherit hostname; inherit username; inherit system; inherit inputs;};
        in nixpkgs.lib.nixosSystem {
            inherit specialArgs;
            inherit system;
            
            modules = [
              ./hosts/nixos
              ./users/${username}
              home-manager.nixosModules.home-manager {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;

                home-manager.users.glom = import ./users/${username}/home.nix;
                home-manager.extraSpecialArgs = inputs // specialArgs;
              }
            ];
          };
    };
  };
}