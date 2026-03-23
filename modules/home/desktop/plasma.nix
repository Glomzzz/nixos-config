{...}: let
  legacyRoot = ./../../..;
in {
  imports = [
    (legacyRoot + "/home/plasma/default.nix")
  ];
}
