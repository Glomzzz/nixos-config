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
      "dialout"
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
  environment.plasma6.excludePackages = [
    pkgs.kdePackages.kate
  ];

  services.displayManager.autoLogin = {
    enable = true;
    user = username;
  };

  nixpkgs.overlays = [
    (final: prev: {
      python3 = prev.python3.override {
        packageOverrides = pySelf: pySuper: {
          cli-helpers = pySuper.cli-helpers.overridePythonAttrs (oldAttrs: {
            doCheck = false;
          });
          face-recognition = pySuper.face-recognition.overrideAttrs (oldAttrs: {
            doInstallCheck = false;
          });
        };
      };
      python3Packages = final.python3.pkgs;
      howdy = let
        pythonDeps = builtins.map (
          dep:
            if dep == "opencv4Full"
            then "opencv4"
            else dep
        );
      in
        (prev.howdy.override {inherit (final) python3;}).overrideAttrs (oldAttrs: {
          pythonEnv = final.python3.buildEnv.override {
            extraLibs = final.lib.attrVals (pythonDeps oldAttrs.passthru.pythonDeps) final.python3.pkgs;
            makeWrapperArgs = [
              "--set"
              "OMP_NUM_THREADS"
              "1"
            ];
          };
          passthru =
            oldAttrs.passthru
            // {
              pythonDeps = pythonDeps oldAttrs.passthru.pythonDeps;
            };
        });
      sub2api = final.callPackage ../../pkgs/sub2api.nix {};
      codex = final.callPackage ../../pkgs/codex.nix {};
      oh-my-codex = final.callPackage ../../pkgs/oh-my-codex.nix {};
      cherry-studio = final.callPackage ../../pkgs/cherry-studio.nix {};
      openldap = prev.openldap.overrideAttrs (oldAttrs: {
        doCheck = false;
      });
    })
  ];

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "26.11";
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
