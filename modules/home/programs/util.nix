{...}: let
  legacyRoot = ./../../..;
in {
  imports = [
    (legacyRoot + "/home/programs/util.nix")
  ];
}
