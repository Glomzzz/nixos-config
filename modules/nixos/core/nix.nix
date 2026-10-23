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
    # The root filesystem is Btrfs; avoid Nix hard-link deduplication, which
    # defeats copy-on-write sharing and adds needless store maintenance cost.
    auto-optimise-store = false;
    download-buffer-size = 524288000;
    min-free = 1 * 1024 * 1024 * 1024;
    max-free = 5 * 1024 * 1024 * 1024;
  };
}
