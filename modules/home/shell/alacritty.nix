{...}: let
  legacyRoot = ./../../..;
in {
  imports = [
    (legacyRoot + "/home/shell/alacritty/default.nix")
  ];
}
