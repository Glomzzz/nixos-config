{config, ...}: let
  d = config.xdg.dataHome;
  c = config.xdg.configHome;
  cache = config.xdg.cacheHome;
in {
  imports = [
    ./kitty.nix
    ./nushell.nix
    ./terminal-tools.nix
    ./starship.nix
    ./ssh.nix
  ];

  home = {
    sessionVariables = {
      LESSHISTFILE = cache + "/less/history";
      LESSKEY = c + "/less/lesskey";
      WINEPREFIX = d + "/wine";

      TERMINAL = "kitty";
      DELTA_PAGER = "less -R";
      MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    };

    sessionPath = [
      "${config.home.homeDirectory}/.local/bin"
    ];

    shellAliases = {
      k = "kubectl";
    };
  };

  programs.ssh.enableDefaultConfig = false;
}
