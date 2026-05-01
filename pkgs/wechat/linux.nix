{
  pname,
  version,
  src,
  meta,
  appimageTools,
  kdePackages,
  libsForQt5,
  writeShellScript,
}: let
  appimageContents = appimageTools.extract {
    inherit pname version src;
    postExtract = ''
      patchelf --replace-needed libtiff.so.5 libtiff.so $out/opt/wechat/wechat
    '';
  };

  launcher = writeShellScript "wechat" ''
    if [[ "$XMODIFIERS" =~ ibus ]]; then
      export QT_IM_MODULE=ibus
      export GTK_IM_MODULE=ibus
      export IBUS_USE_PORTAL=1
    else
      export XMODIFIERS=@im=fcitx
      export QT_IM_MODULE=fcitx
      export GTK_IM_MODULE=fcitx
      export SDL_IM_MODULE=fcitx
      export GLFW_IM_MODULE=ibus
      export QT_PLUGIN_PATH=${libsForQt5.fcitx5-qt}/lib/qt-5.15.18/plugins:${kdePackages.fcitx5-qt}/lib/qt-6/plugins:''${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}
    fi

    exec @wrapped@ "$@"
  '';
in
  appimageTools.wrapAppImage {
    inherit pname version meta;

    src = appimageContents;

    extraInstallCommands = ''
      mkdir -p $out/share/applications
      cp ${appimageContents}/wechat.desktop $out/share/applications/

      mkdir -p $out/share/icons/hicolor/256x256/apps
      cp ${appimageContents}/wechat.png $out/share/icons/hicolor/256x256/apps/

      substituteInPlace $out/share/applications/wechat.desktop \
        --replace-fail AppRun wechat

      mv $out/bin/wechat $out/bin/.wechat-wrapped
      install -m755 ${launcher} $out/bin/wechat

      substituteInPlace $out/bin/wechat \
        --replace-fail @wrapped@ $out/bin/.wechat-wrapped
    '';
  }
