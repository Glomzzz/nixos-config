{
  pkgs,
  inputs,
  system,
  ...
}: let
  nix-alien = inputs.nix-alien-source.packages.${system}.nix-alien;
  sevenZip = import ./7zip.nix {inherit pkgs;};
in {
  home.packages = with pkgs; [
    age
    just
    fastfetch
    zip
    unzip
    sevenZip
    ripgrep
    fd
    mandible
    nix-alien
    curl
    sysstat
    usbutils
    wget
    yq-go
  ];
}
