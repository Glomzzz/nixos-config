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
  # Track the latest stable kernel from the locked nixpkgs (not an RC).
  # 7.2.1 previously broke eDP mode detection on this machine: validate the
  # laptop panel after booting an update and retain a known-good generation.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  system.stateVersion = "26.11";
}
