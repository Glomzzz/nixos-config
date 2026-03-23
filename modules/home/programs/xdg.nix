{...}: let
  legacyRoot = ./../../..;
in {
  imports = [
    (legacyRoot + "/home/programs/xdg.nix")
  ];
}
