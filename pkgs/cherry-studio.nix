{
  lib,
  fetchurl,
  appimageTools,
  symlinkJoin,
  runCommand,
}: let
  pname = "cherry-studio";
  version = "1.9.4";
  src = fetchurl {
    url = "https://github.com/CherryHQ/cherry-studio/releases/download/v${version}/Cherry-Studio-${version}-x86_64.AppImage";
    hash = "sha256-79sccZCTuhahtMP9OIEI165Ce/ZppUxzf5Q/Vmz6isc=";
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname version src;
  };

  app = appimageTools.wrapType2 {
    inherit pname version src;

    extraPkgs = pkgs:
      with pkgs; [
        libsecret
        libnotify
      ];

    meta = {
      description = "Desktop client for LLMs and AI tools";
      homepage = "https://github.com/CherryHQ/cherry-studio";
      license = lib.licenses.gpl3Plus;
      mainProgram = "cherry-studio";
      platforms = ["x86_64-linux"];
      maintainers = [];
    };
  };

  icon = runCommand "${pname}-${version}-icon" {} ''
    install -Dm444 ${appimageContents}/CherryStudio.png \
      $out/share/icons/hicolor/512x512/apps/cherry-studio.png
  '';
in
  symlinkJoin {
    name = "${pname}-${version}";
    paths = [
      app
      icon
    ];
    inherit (app) meta;
  }
