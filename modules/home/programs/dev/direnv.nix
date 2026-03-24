{...}: {
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableNushellIntegration = true;
    silent = true;
    config = {
      hide_env_diff = true;
    };
  };
}
