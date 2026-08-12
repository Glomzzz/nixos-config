{config, ...}: let
  c = config.xdg.configHome;
  cache = config.xdg.cacheHome;
in {
  imports = [
    ./foot.nix
    ./fish.nix
    ./ssh.nix
    ./starship.nix
  ];

  home = {
    sessionVariables = {
      LESSHISTFILE = cache + "/less/history";
      LESSKEY = c + "/less/lesskey";
      TERMINAL = "foot";
      MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    };

    sessionPath = [
      "${config.home.homeDirectory}/.local/bin"
    ];
  };
}
