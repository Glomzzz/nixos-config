{pkgs,...} : let
  nix-alien = import (
    builtins.fetchTarball "https://github.com/thiagokokada/nix-alien/tarball/master"
  ) { }.nix-alien;
in {
    environment.systemPackages = with pkgs; [
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
  ];
}