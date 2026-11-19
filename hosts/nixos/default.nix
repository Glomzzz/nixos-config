{
  lib,
  username,
  hostname,
  pkgs,
  ...
}: {
  imports = [
    ./overlays.nix
    ../../hardware
    ../../modules/nixos
    (../../users + "/${username}")
    ../../cachix.nix
  ];

  networking.hostName = hostname;
  # Track the latest stable kernel from the locked nixpkgs (not an RC).
  # Hardware profiles may override this; the zephyrus profile pins its own.
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

  # Compatibility baseline, NOT the installed NixOS release. Earlier upgrades
  # already advanced this value; keep the current baseline rather than undoing
  # potentially migrated state. See docs/state-version.md before changing it.
  system.stateVersion = "26.11";
}
