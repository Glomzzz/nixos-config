{
  description = "Glom's Flake configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/";
    nixpkgs-2505.url = "github:NixOS/nixpkgs/nixos-25.05/";
    nixpkgs-2411.url = "github:NixOS/nixpkgs/nixos-24.11/";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-alien-source.url = "github:thiagokokada/nix-alien";
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    nixvim-source = {
      url = "github:Glomzzz/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    nixpkgs,
    nixpkgs-2505,
    nixpkgs-2411,
    home-manager,
    ...
  }: {
    nixosConfigurations = {
      nixos = let
        system = "x86_64-linux";
        hostname = "nixos";
        username = "glom";
        usernameFull = "Glom Zhao";
        email = "glom@skillw.com";
        specialArgs = {
          inherit hostname;
          inherit username;
          inherit usernameFull;
          inherit email;
          inherit system;
          inherit inputs;
        };
        overlay-2411 = final: prev: {
          legacy-2411 = import nixpkgs-2411 {
            inherit system;
            config.allowUnfree = true;
          };
        };
        overlay-stable = final: prev: {
          stable = import nixpkgs-2505 {
            inherit system;
            config.allowUnfree = true;
          };
        };
      in
        nixpkgs.lib.nixosSystem {
          inherit specialArgs;
          inherit system;
          modules = [
            ({
              config,
              pkgs,
              ...
            }: {nixpkgs.overlays = [overlay-2411 overlay-stable];})
            ./hosts/nixos
            ./users/${username}
            home-manager.nixosModules.home-manager
            {
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
