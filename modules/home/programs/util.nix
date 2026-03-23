{pkgs, ...}: {
  home.packages = with pkgs; [
    (callPackage ../../../pkgs/tracy/package.nix {})
    typst
    usbutils
    yq-go
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
