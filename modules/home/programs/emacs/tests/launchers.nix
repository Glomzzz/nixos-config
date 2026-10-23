{
  pkgs,
  home,
}: let
  settings = pkgs.writeText "emacs-launchers.json" (builtins.toJSON {
    wrapper = home.home.file.".local/bin/emc".source;
    kitty = "${home.programs.kitty.package}/bin/kitty";
    emc = "${home.home.homeDirectory}/.local/bin/emc";
    environment = {
      inherit (home.home.sessionVariables) EDITOR VISUAL SUDO_EDITOR ALTERNATE_EDITOR;
    };
    gitEditor = home.programs.git.settings.core.editor;
    generatedClient = home.services.emacs.client.enable;
    desktopEntries =
      builtins.mapAttrs (_: entry: {
        inherit (entry) exec terminal mimeType;
      })
      home.xdg.desktopEntries;
    associations = home.xdg.mimeApps.defaultApplications;
    editorShortcut = home.programs.niri.settings.binds."Mod+Return".action.spawn;
    directoryShortcut = home.programs.niri.settings.binds."Mod+E".action.spawn;
    niriEnvironment = home.programs.niri.settings.environment;
  });
in
  pkgs.runCommand "emacs-launchers-check"
  {nativeBuildInputs = [pkgs.python3 pkgs.shellcheck];}
  ''
    shellcheck --shell=sh ${home.home.file.".local/bin/emc".source}
    python3 ${./launchers.py} ${settings}
    touch "$out"
  ''
