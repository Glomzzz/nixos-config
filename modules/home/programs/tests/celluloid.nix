{
  pkgs,
  home,
}: let
  player =
    pkgs.lib.findSingle
    (p: pkgs.lib.getName p == "celluloid")
    (throw "celluloid missing from home.packages")
    (throw "multiple celluloid packages in home.packages")
    home.home.packages;
  settings = pkgs.writeText "celluloid-settings.json" (builtins.toJSON {
    package = player;
    configFile = home.xdg.configFile."celluloid/mpv.conf".source;
    preferences = home.dconf.settings."io/github/celluloid-player/celluloid";
    associations =
      pkgs.lib.filterAttrs
      (name: _: pkgs.lib.hasPrefix "video/" name || pkgs.lib.hasPrefix "audio/" name)
      home.xdg.mimeApps.defaultApplications;
    libmpv = "${pkgs.mpv-unwrapped}/lib/libmpv.so";
  });
in
  assert !home.programs.mpv.enable;
  assert !(builtins.hasAttr "mpv/mpv.conf" home.xdg.configFile);
    pkgs.runCommand "celluloid-check"
    {nativeBuildInputs = [pkgs.python3];}
    ''
      python3 ${./celluloid.py} ${settings}
      touch "$out"
    ''
