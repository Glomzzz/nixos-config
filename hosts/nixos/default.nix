{
  username,
  hostname,
  pkgs,
  ...
}: {
  imports = [
    ./networking.nix
    ./overlays.nix
    ../../hardware/zephyrus
    ../../modules/nixos
    (../../users + "/${username}")
    ../../cachix.nix
  ];

  networking.hostName = hostname;
  # Keep the Zephyrus display stack on the maintained 6.18 LTS kernel. The
  # 7.2.1 kernel from the latest nixpkgs snapshot fails to retrieve the panel
  # link information on this hybrid NVIDIA system, leaving eDP-1 connected but
  # with no modes (and therefore black) while HDMI still works.
  boot.kernelPackages = pkgs.linuxPackages_6_18;

  system.stateVersion = "26.11";
}
