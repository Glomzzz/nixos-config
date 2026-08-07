_: {
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
