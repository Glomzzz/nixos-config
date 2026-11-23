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
    nixos-secrets.url = "github:Glomzzz/nixos-secrets";
    # Nix substituter proxy (see modules/services/nixos/selector4nix.nix). It keeps
    # its own nixpkgs pin so its binary cache entries match.
    selector4nix.url = "github:StarryReverie/selector4nix";
    nix-alien-source.url = "github:thiagokokada/nix-alien";
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
      url = "github:Supreeeme/xwayland-satellite/d10a015a9423c360d723ab7d65f824db662cbbd7";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-overlay.follows = "";
    };
  };

  outputs = inputs @ {
    nixpkgs,
    home-manager,
    nixos-secrets,
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

    packages = forAllSystems (system: let
      pkgs = (pkgsFor system).extend (import ./pkgs);
    in {
      inherit (pkgs) phono-core phono-fcitx5-addon;
    });

    # Shared host modules for other flakes that bring their own hardware. `shared` is
    # everything in hosts/nixos except the hardware selector; `hardware-common` is the
    # hardware-independent set that every profile imports.
    nixosModules = {
      shared = ./hosts/nixos/shared.nix;
      hardware-common = ./hardware/common;
    };

    nixosConfigurations = {
      nixos = let
        system = "x86_64-linux";
        hostname = "nixos";
        username = "glom";
        sensitive = nixos-secrets.sensitive.identities.${username};
        inherit (nixos-secrets) secretFiles;
        specialArgs = {
          inherit hostname;
          inherit username;
          inherit system;
          inherit inputs;
          inherit secretFiles;
          inherit (sensitive) usernameFull email;
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
