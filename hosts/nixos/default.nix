{ config
, pkgs
, lib
, username
, hostname
, ...
}: {
  imports = [
    ../../hardware/zephyrus
    ../../system
    ../../cachix.nix
  ];

  networking.hostName = hostname;
  services.resolved.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [ "networkmanager" "wheel" ];
  };

  programs.clash-verge = {
    enable = true;
    serviceMode = true;
    tunMode = true;
  };
  systemd.services.clash-verge = {
    enable = true;
    description = "Clash Verge Service Mode";
    serviceConfig = {
      ExecStart = "${config.programs.clash-verge.package}/bin/clash-verge-service";
      Restart = "on-failure";
    };
    wantedBy = [ "multi-user.target" ];
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

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
