_: {
  # Niri has no full desktop power manager. UPower owns the critical action;
  # poweralertd reports low/critical levels through the existing notifier.
  services.poweralertd.enable = true;
}
