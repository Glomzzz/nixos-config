{
  username,
  hostname,
  inputs,
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
  # Keep the Zephyrus display stack on the known-good 7.2.0 kernel. The
  # current nixpkgs 7.2.1 kernel fails to retrieve the panel link information
  # on this hybrid NVIDIA system, leaving eDP-1 connected but with no modes
  # (and therefore black) while HDMI still works.
  boot.kernelPackages =
    (import inputs.nixpkgs-kernel-7-2-0 {
      inherit (pkgs.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    }).linuxPackages_7_2;

  system.stateVersion = "26.11";
}
