{...}: let
  legacyRoot = ./../../..;
in {
  imports = [
    (legacyRoot + "/home/shell/starship.nix")
  ];
}
