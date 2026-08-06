{
  cmake,
  lib,
  libcava,
  ncurses,
  ninja,
  pipewire,
  pkg-config,
  qt6,
  qt6Packages,
  stdenv,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "clavis-shell-core";
  version = "0-unstable-2026-07-31";

  src = lib.cleanSourceWith {
    src = ../quickshell;
    filter = path: type:
      (lib.cleanSourceFilter path type)
      && !(lib.hasInfix "/core/build" path);
  };

  strictDeps = true;

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    libcava
    ncurses
    pipewire
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtshadertools
    qt6.qttools
    qt6Packages.qtkeychain
  ];

  configurePhase = ''
    runHook preConfigure

    cmake -S core -B build -G Ninja \
      -DBUILD_TESTING=ON \
      -DCLAVIS_INSTALL_RAPL_CAPABILITY=OFF \
      -DCMAKE_BUILD_RPATH_USE_ORIGIN=ON \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="$out"

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    cmake --build build --parallel "$NIX_BUILD_CORES"
    runHook postBuild
  '';

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    env -u QT_QPA_PLATFORMTHEME \
      QT_QPA_PLATFORM=offscreen \
      ctest --test-dir build --output-on-failure
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    cmake --install build

    install -d "$out/lib/qt-6/qml" "$out/share/clavis-shell"
    cp -a build/Clavis build/M3Shapes "$out/lib/qt-6/qml/"
    cp -a ${finalAttrs.src}/. "$out/share/clavis-shell/"

    runHook postInstall
  '';

  postFixup = ''
    for library in \
      "$out"/lib/qt-6/qml/Clavis/*/*.so \
      "$out"/lib/qt-6/qml/M3Shapes/*.so; do
      if ldd "$library" | grep -Fq "not found"; then
        echo "$library has unresolved libraries" >&2
        ldd "$library" >&2
        exit 1
      fi
    done
  '';

  meta = {
    description = "Native plugins and configuration sources for Clavis Shell";
    homepage = "https://github.com/StatIndet/quickshell";
    license = with lib.licenses; [
      asl20
      gpl3Only
      lgpl3Only
      mit
      ofl
    ];
    mainProgram = "key";
    platforms = lib.platforms.linux;
  };
})
