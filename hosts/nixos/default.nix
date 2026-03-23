{
  username,
  hostname,
  ...
}:
{
  imports = [
    ./networking.nix
    ../../hardware/zephyrus
    ../../modules/nixos
    (../../users + "/${username}")
    ../../cachix.nix
  ];

  networking.hostName = hostname;
  services.resolved.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  # Enable the X server (for compatibility)
  services.xserver.enable = true;
  # Enable the Simple Desktop Display Manager
  services.displayManager.sddm.enable = true;
  # Enable the KDE Plasma 6 desktop
  services.desktopManager.plasma6.enable = true;

  services.displayManager.autoLogin.enable = false;

  nixpkgs.overlays = [
    (final: _prev: {
      sub2api = final.callPackage ../../pkgs/sub2api.nix {};
    })
  ];

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "26.05";
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
}
