{pkgs, lib, ...}: {
  environment.systemPackages = with pkgs; [
    kdePackages.kwallet-pam
  ];

  # Disabled since KWallet is disabled in plasma.nix for auto-login
  security.pam.services.kde.kwallet.enable = lib.mkForce false;
}
