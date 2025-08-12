{pkgs,inputs,system,...} : {
    environment.systemPackages = let
      nix-alien = inputs.nix-alien-source.packages.${system}.nix-alien;
    in with pkgs; [
      input-remapper
      wget
      curl
      git
      sysstat
      lm_sensors # for `sensors` command
      fastfetch
      xfce.thunar # xfce4's file manager
      nnn # terminal file manager

      # archives
      zip
      unzip
      p7zip

      # utils
      just
      ripgrep
      wine
      nix-alien
      gnumake
      fd
      xclip
  ];
}
