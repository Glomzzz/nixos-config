{
  description = "Glom's Flake configuration";

  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/";
    # nixpkgs-2505.url = "github:NixOS/nixpkgs/nixos-25.05/";
    # nixpkgs-2411.url = "github:NixOS/nixpkgs/nixos-24.11/";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
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
    nix-openclaw = {
      url = "github:openclaw/nix-openclaw";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    home-manager,
    ...
  }: let
    systems = ["x86_64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    pkgsFor = system:
      import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
  in {
    formatter = forAllSystems (system: (pkgsFor system).alejandra);

    checks = forAllSystems (system: let
      pkgs = pkgsFor system;
    in {
      formatting =
        pkgs.runCommand "alejandra-check" {
          nativeBuildInputs = [pkgs.alejandra];
          src = ./.;
        } ''
          cd "$src"
          alejandra --check .
          touch "$out"
        '';

      dead-code =
        pkgs.runCommand "deadnix-check" {
          nativeBuildInputs = [pkgs.deadnix];
          src = ./.;
        } ''
          cd "$src"
          deadnix --fail .
          touch "$out"
        '';

      lint =
        pkgs.runCommand "statix-check" {
          nativeBuildInputs = [pkgs.statix];
          src = ./.;
        } ''
          cd "$src"
          statix check .
          touch "$out"
        '';

      host = self.nixosConfigurations.nixos.config.system.build.toplevel;
    });

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
      in
        nixpkgs.lib.nixosSystem {
          inherit specialArgs;
          inherit system;
          modules = [
            ./hosts/nixos
            home-manager.nixosModules.home-manager
          ];
        };
    };
  };
}
