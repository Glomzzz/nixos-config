{config, ...}: {
  services = {
    upower = {
      enable = true;
      usePercentageForPolicy = true;
      percentageLow = 20;
      percentageCritical = 10;
      percentageAction = 3;
      criticalPowerAction = "Hibernate";
    };

    # Enables inspection/metadata refresh, not unattended firmware installation.
    fwupd.enable = true;
  };

  # Existing swap partition, not a new swap/encryption migration. Keep resume
  # independent of EFI's automatic discovery; verify manually before relying on
  # low-battery hibernation. Swap and the hibernation image are still plaintext.
  boot.resumeDevice = (builtins.head config.swapDevices).device;
}
