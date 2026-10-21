{
  config,
  pkgs,
}: let
  settings = pkgs.writeText "authentication-settings.json" (builtins.toJSON {
    pam = builtins.mapAttrs (_: service: service.text) config.security.pam.services;
    locker = config.home-manager.users.glom.xdg.configFile."swaylock/config".text;
    globalHowdy = config.security.pam.howdy.enable;
    globalU2f = config.security.pam.u2f.enable;
    hostname = config.networking.hostName;
  });
in
  pkgs.runCommand "authentication-check"
  {
    nativeBuildInputs = [pkgs.python3 pkgs.stdenv.cc];
    buildInputs = [pkgs.pam];
  }
  ''
    cc -Wall -Wextra -Werror ${./pam-check.c} -o pam-check -lpam
    python3 ${./authentication.py} ${settings} ${pkgs.pam}/lib/security ./pam-check
    touch "$out"
  ''
