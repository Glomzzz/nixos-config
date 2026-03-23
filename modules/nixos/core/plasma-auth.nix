{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    kdePackages.kwallet-pam
  ];

  security.pam.services.kde.kwallet.enable = true;
}
