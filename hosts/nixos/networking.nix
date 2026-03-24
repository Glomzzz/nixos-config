{
  lib,
  pkgs,
  ...
}: {
  networking.useDHCP = lib.mkDefault true;
  environment.systemPackages = with pkgs; [
    easytier
  ];
}
