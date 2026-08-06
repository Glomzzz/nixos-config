{pkgs, ...}: {
  environment.systemPackages = with pkgs.kdePackages; [
    kwallet
    kwallet-pam
    kwalletmanager
  ];

  # Plasma normally wires this up for graphical sessions. Keep the integration
  # explicit now that KWallet is used without the Plasma desktop.
  security.pam.services.login.kwallet.enable = true;

  # Keep KWallet's Secret portal backend available without installing the
  # Plasma desktop.
  xdg.portal.extraPortals = [
    pkgs.kdePackages.kwallet
  ];
}
