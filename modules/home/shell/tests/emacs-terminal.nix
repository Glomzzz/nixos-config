{
  pkgs,
  home,
}: let
  settings = pkgs.writeText "emacs-terminal-settings.json" (builtins.toJSON {
    terminal = home.home.sessionVariables.TERMINAL;
    desktopTerminals = home.xdg.terminal-exec.settings.default;
    kittyConfig = pkgs.writeText "tested-kitty.conf" home.xdg.configFile."kitty/kitty.conf".text;
    kitty = "${home.programs.kitty.package}/bin/kitty";
    emacs = "${home.programs.emacs.finalPackage}/bin/emacs";
    client = "${home.programs.emacs.finalPackage}/bin/emacsclient";
    environment = home.systemd.user.services.emacs.Service.Environment;
  });
in
  pkgs.runCommand "emacs-terminal-check"
  {nativeBuildInputs = [pkgs.python3];}
  ''
    python3 ${./emacs-terminal.py} ${settings}
    touch "$out"
  ''
