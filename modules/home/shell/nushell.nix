{...}: let
  legacyRoot = ./../../..;
in {
  imports = [
    (legacyRoot + "/home/shell/nushell/default.nix")
  ];
}
