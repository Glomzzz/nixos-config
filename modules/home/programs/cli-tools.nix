{
  pkgs,
  inputs,
  system,
  ...
}:
let
  nix-alien = inputs.nix-alien-source.packages.${system}.nix-alien;
in
{
  home.packages = with pkgs; [
    just
    fastfetch
    zip
    unzip
    p7zip
    ripgrep
    fd
    nix-alien
  ];
}
