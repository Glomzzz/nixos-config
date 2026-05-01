{
  username,
  hostname,
  pkgs,
  ...
}: {
  imports = [
    ./networking.nix
    ../../hardware/zephyrus
    ../../modules/nixos
    (../../users + "/${username}")
    ../../cachix.nix
  ];

  networking.hostName = hostname;
  services.resolved.enable = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
  };

  # Enable the X server (for XWayland compatibility)
  services.xserver.enable = true;
  # Enable the Simple Desktop Display Manager with Wayland support
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };
  # Enable the KDE Plasma 6 desktop with Wayland
  services.desktopManager.plasma6.enable = true;

  services.displayManager.autoLogin = {
    enable = true;
    user = username;
  };

  nixpkgs.overlays = [
    (final: prev: {
      sub2api = final.callPackage ../../pkgs/sub2api.nix {};
      codex = final.callPackage ../../pkgs/codex.nix {};
      oh-my-codex = final.callPackage ../../pkgs/oh-my-codex.nix {};
      cherry-studio = final.callPackage ../../pkgs/cherry-studio.nix {};
      python3Packages = prev.python3Packages.overrideScope (pySelf: pySuper: {
        cli-helpers = pySuper.cli-helpers.overridePythonAttrs (oldAttrs: {
          doCheck = false;
        });
      });
      openldap = prev.openldap.overrideAttrs (oldAttrs: {
        doCheck = false;
      });
    })
  ];

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "26.05";
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    min-free = 1 * 1024 * 1024 * 1024;
    max-free = 5 * 1024 * 1024 * 1024;
  };
}
