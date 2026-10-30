{
  pkgs,
  home,
}: let
  settings = pkgs.writeText "emacs-launchers.json" (builtins.toJSON {
    wrapper = home.home.file.".local/bin/emc".source;
    majjWrapper = home.home.file.".local/bin/majj".source;
    majjExecutable = home.home.file.".local/bin/majj".executable;
    packages = map pkgs.lib.getName home.home.packages;
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
    calcShortcut = home.programs.niri.settings.binds."Mod+Semicolon".action.spawn;
    emailShortcut = home.programs.niri.settings.binds."Mod+Apostrophe".action.spawn;
    fishCalc = home.programs.fish.functions.calc.body;
    fishEmail = home.programs.fish.functions.email.body;
    niriEnvironment = home.programs.niri.settings.environment;
  });
in
  pkgs.runCommand "emacs-launchers-check"
  {nativeBuildInputs = [pkgs.python3 pkgs.shellcheck];}
  ''
    shellcheck --shell=sh ${home.home.file.".local/bin/emc".source} ${home.home.file.".local/bin/majj".source}
    python3 ${./launchers.py} ${settings}
    touch "$out"
  ''
