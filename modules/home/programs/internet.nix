{...}: let
  legacyRoot = ./../../..;
in {
  imports = [
    (legacyRoot + "/home/programs/internet.nix")
  ];
}
