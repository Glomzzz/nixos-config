
{ pkgs, ... }: {
  imports = [
    ./java.nix
    ./rust.nix
    ./other.nix
  ];
}
