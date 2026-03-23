{...}: let
  legacyRoot = ./../../..;
in {
  imports = [
    (legacyRoot + "/home/fcitx5/default.nix")
  ];
}
