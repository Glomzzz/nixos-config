{
  lib,
  fetchurl,
  appimageTools,
  symlinkJoin,
  runCommand,
}: let
  pname = "cherry-studio";
  version = "1.9.12";
  src = fetchurl {
    url = "https://github.com/CherryHQ/cherry-studio/releases/download/v${version}/Cherry-Studio-${version}-x86_64.AppImage";
    hash = "sha256-s1lgODX6K3Ze88hfpISo2BL1xLzykjEMJTX8Zzo0Nh0=";
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
