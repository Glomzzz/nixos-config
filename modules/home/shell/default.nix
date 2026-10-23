{config, ...}: let
  c = config.xdg.configHome;
  cache = config.xdg.cacheHome;
in {
  imports = [
    ./foot.nix
    ./kitty.nix
    ./fish.nix
    ./ssh.nix
    ./starship.nix
  ];

  home = {
    sessionVariables = {
      LESSHISTFILE = cache + "/less/history";
      LESSKEY = c + "/less/lesskey";
      TERMINAL = "kitty";
      MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    };

    sessionPath = [
      "${config.home.homeDirectory}/.local/bin"
    ];
  };
}
