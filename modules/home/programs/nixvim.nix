{...}: let
  legacyRoot = ./../../..;
in {
  imports = [
    (legacyRoot + "/home/nixvim/default.nix")
  ];
}
