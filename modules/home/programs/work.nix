{...}: let
  legacyRoot = ./../../..;
in {
  imports = [
    (legacyRoot + "/home/programs/work.nix")
  ];
}
