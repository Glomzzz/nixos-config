{ inputs, system, ... }:
{ 
  home.packages = let
      nixvim = inputs.nixvim-source.packages.${system}.default;
    in [
      nixvim
    ];
}
