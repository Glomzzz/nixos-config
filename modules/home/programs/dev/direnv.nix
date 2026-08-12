_: {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableFishIntegration = true;
    silent = true;
    config = {
      hide_env_diff = true;
    };
  };
}
