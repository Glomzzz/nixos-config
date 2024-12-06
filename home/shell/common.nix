{
  pkgs,
  ...
}:
# nix tooling
{
  home.packages = with pkgs; [
    alejandra
    deadnix
    statix
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    # enableNushellIntegration = true;
    silent = true;
    config = {
      hide_env_diff = true;
    };
  };
}