{
  inputs,
  username,
  hostname,
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

  nix.settings.trusted-users = ["root" "@wheel" username];

  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = ["networkmanager" "wheel"];
  };

  # Enable the X server (for compatibility)
  services.xserver.enable = true;
  # Enable the Simple Desktop Display Manager
  services.displayManager.sddm.enable = true;
  # Enable the KDE Plasma 6 desktop
  services.desktopManager.plasma6.enable = true;

  # Enable automatic login for the user.
  services.displayManager.autoLogin.enable = true;

  services.displayManager.autoLogin.user = username;

  security.pam.services.kde.kwallet.enable = true;

  nixpkgs.overlays = [
    inputs.nix-openclaw.overlays.default
    (final: prev: {
      codex = final.callPackage ../../pkgs/codex.nix {};
      sub2api = final.callPackage ../../pkgs/sub2api.nix {};

      mycli = prev.mycli.overridePythonAttrs (old: {
        pythonRelaxDeps = (old.pythonRelaxDeps or []) ++ ["sqlglot"];
        nativeBuildInputs = (old.nativeBuildInputs or [])
          ++ [final.python3Packages.pythonRelaxDepsHook];
      });
    })
  ];

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "26.05";
  nix.settings.experimental-features = ["nix-command" "flakes"];
}
