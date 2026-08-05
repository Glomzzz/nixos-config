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
  boot.kernelPackages = pkgs.linuxPackages_latest;

  users.users.${username} = {
    isNormalUser = true;
    description = username;
    # User-owned NetworkManager profiles use the KWallet-backed secret agent.
    # System-wide profile changes should continue to require Polkit approval.
    extraGroups = [
      "dialout"
      "wheel"
    ];
  };

  services = {
    resolved.enable = true;

    # Hyprland and SDDM run natively on Wayland. Legacy X11 applications use
    # the separately enabled XWayland compatibility server.
    xserver.enable = false;

    displayManager = {
      # Enable the Simple Desktop Display Manager with Wayland support
      sddm = {
        enable = true;
        wayland.enable = true;
      };

      autoLogin = {
        enable = true;
        user = username;
      };
    };

    # Enable the KDE Plasma 6 desktop with Wayland
    desktopManager.plasma6.enable = true;
  };
  environment.plasma6.excludePackages = [
    pkgs.kdePackages.kate
  ];

  nixpkgs.overlays = [
    (import ../../pkgs)
    (final: prev: {
      python3 = prev.python3.override {
        packageOverrides = _: pySuper: {
          cli-helpers = pySuper.cli-helpers.overridePythonAttrs (_: {
            doCheck = false;
          });
          face-recognition = pySuper.face-recognition.overrideAttrs (_: {
            doInstallCheck = false;
          });
        };
      };
      python3Packages = final.python3.pkgs;
      # powerprofilesctl aborts during PyGObject teardown under Python 3.14.
      power-profiles-daemon = prev.power-profiles-daemon.override {
        python3 = final.python313;
      };
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
      openldap = prev.openldap.overrideAttrs (_: {
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
