{
  config,
  pkgs,
  ...
}: let
  emacs = config.programs.emacs.finalPackage;
  emc = "${config.home.homeDirectory}/.local/bin/emc";
  noSpawnEditor = "${pkgs.coreutils}/bin/false";
in {
  home = {
    file = {
      ".local/bin/emc" = {
        executable = true;
        source = pkgs.replaceVars ./emc.sh {
          emacsclient = "${emacs}/bin/emacsclient";
          kitty = "${config.programs.kitty.package}/bin/kitty";
          inherit noSpawnEditor;
          # Stable across package garbage collection and generation changes.
          systemctl = "/run/current-system/sw/bin/systemctl";
        };
      };
      ".local/bin/majj" = {
        executable = true;
        source = pkgs.replaceVars ./majj.sh {inherit emc;};
      };
    };

    sessionVariables = {
      EDITOR = emc;
      VISUAL = emc;
      SUDO_EDITOR = emc;
      # An empty alternate editor starts an unmanaged daemon on the same socket.
      ALTERNATE_EDITOR = noSpawnEditor;
    };
  };
}
