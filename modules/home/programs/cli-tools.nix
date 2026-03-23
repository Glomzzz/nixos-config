{
  pkgs,
  inputs,
  system,
  ...
}: let
  nix-alien = inputs.nix-alien-source.packages.${system}.nix-alien;
in {
  home.packages = with pkgs; [
    git
    fastfetch
    thunar
    nnn
    zip
    unzip
    p7zip
    just
    ripgrep
    gnumake
    fd
    xclip
    nix-alien
  ];
}
