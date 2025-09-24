{
  pkgs,
  system,
  ...
}: {
  home.packages = with pkgs; [
    typst
    usbutils
    yq-go # https://github.com/mikefarah/yq
    alejandra
    deadnix
    statix
  ];
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
