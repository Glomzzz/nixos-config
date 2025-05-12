{pkgs,inputs,system,...} : {
    environment.systemPackages = let
      nix-alien = inputs.nix-alien-source.packages.${system}.nix-alien;
    in with pkgs; [
      vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
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
      just
      ripgrep
      wine
      nix-alien
      gnumake
  ];
}