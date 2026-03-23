{...}: let
  legacyRoot = ./../../..;
in {
  imports = [
    (legacyRoot + "/home/programs/git.nix")
  ];
}
