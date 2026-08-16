{
  description = "Glom's Flake configuration";

  inputs = {
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
    # Local Ryzenbit compiler checkout (the repository at
    # ~/git/ryzenbit); its flake exposes packages.ryzenbit.
    ryzenbit.url = "path:/home/glom/git/ryzenbit";
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Pinned to PR #452, which adds compositor-side scaling for X11 clients.
    # Release 0.8.2 in nixpkgs derives one X-wide scale as the *minimum* of all
    # output scales and then positions each XRandR output at niri's logical
    # coordinate while sizing it in native pixels. Those two coordinate spaces
    # disagree whenever the scales differ, so the X rectangles overlap and no
    # X11 client can tell which monitor its window is on. This revision makes
    # the X screen a uniform multiple of niri's logical space instead, which is
    # what allows per-monitor scaling to work at all; see
    # hardware/zephyrus/gpu for the scale that goes with it.
    #
    # Pinned by revision rather than tracking a branch: this is an unmerged PR,
    # so its head can be rebased or force-pushed out from under us.
    xwayland-satellite = {
      url = "github:Supreeeme/xwayland-satellite/0a95f18d9fd254e3f42e0b4e4132a59084b18b98";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "";
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

    checks = forAllSystems (
      system: let
        pkgs = pkgsFor system;
      in {
        formatting =
          pkgs.runCommand "alejandra-check"
          {
            nativeBuildInputs = [pkgs.alejandra];
            src = ./.;
          }
          ''
            cd "$src"
            alejandra --check .
            touch "$out"
          '';

        dead-code =
          pkgs.runCommand "deadnix-check"
          {
            nativeBuildInputs = [pkgs.deadnix];
            src = ./.;
          }
          ''
            cd "$src"
            deadnix --fail .
            touch "$out"
          '';

        lint =
          pkgs.runCommand "statix-check"
          {
            nativeBuildInputs = [pkgs.statix];
            src = ./.;
          }
          ''
            cd "$src"
            statix check .
            touch "$out"
          '';

        host = self.nixosConfigurations.nixos.config.system.build.toplevel;
      }
    );

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
