_: {
  # Keep recent rollback generations instead of deleting everything but the
  # current system. Explicit known-good GC roots survive age-based pruning.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    randomizedDelaySec = "45min";
    persistent = true;
    options = "--delete-older-than 30d";
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    download-buffer-size = 524288000;
    min-free = 1 * 1024 * 1024 * 1024;
    max-free = 5 * 1024 * 1024 * 1024;
  };
}
