{
  lib,
  stdenv,
  fetchFromGitHub,
  gradle_9,
  jre,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  xxd,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "logisim-evolution";
  version = "5.0.0";

  src = fetchFromGitHub {
    owner = "logisim-evolution";
    repo = "logisim-evolution";
    tag = "v${finalAttrs.version}";
    hash = "sha256-PHcsNcn8quraSFBqial5DyS89cO6NjRRq3r7UcvFm6Y=";
  };

  nativeBuildInputs = [
    gradle_9
    makeWrapper
    copyDesktopItems
  ];

  # Maven/Gradle dependencies come from the recorded proxy cache in deps.json.
  # Refresh it by running mitmCache.updateScript from the repository root.
  mitmCache = gradle_9.fetchDeps {
    pkg = finalAttrs.finalPackage;
    data = ./deps.json;
  };
  # nixpkgs' default nixDownloadDeps task does not work with this build on
  # Gradle 9, so the updater resolves the build and test classpaths directly.
  gradleUpdateTask = "shadowJar test";

  # Build the shadow (fat) jar, the same layout as the upstream release asset.
  gradleBuildTask = "shadowJar";

  # HexFileTest shells out to xxd to cross-check its binary output.
  nativeCheckInputs = [xxd];
  doCheck = true;

  installPhase = ''
    runHook preInstall

    install -Dm444 build/libs/logisim-evolution-${finalAttrs.version}-all.jar \
      $out/share/java/logisim-evolution.jar
    install -Dm444 artwork/logisim-evolution-icon.svg \
      $out/share/icons/hicolor/scalable/apps/logisim-evolution.svg

    makeWrapper ${jre}/bin/java $out/bin/logisim-evolution \
      --add-flags "--enable-native-access=ALL-UNNAMED -jar $out/share/java/logisim-evolution.jar" \
      --set _JAVA_AWT_WM_NONREPARENTING 1

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "logisim-evolution";
      desktopName = "Logisim-evolution";
      genericName = "Digital logic design tool and simulator";
      comment = finalAttrs.meta.description;
      exec = "logisim-evolution %f";
      icon = "logisim-evolution";
      categories = ["Education" "Electronics"];
    })
  ];

  meta = {
    description = "Digital logic designer and simulator";
    homepage = "https://github.com/logisim-evolution/logisim-evolution";
    changelog = "https://github.com/logisim-evolution/logisim-evolution/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Only;
    mainProgram = "logisim-evolution";
    platforms = lib.platforms.linux;
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryBytecode # Maven dependencies from the mitm cache
    ];
  };
})
