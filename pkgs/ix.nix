{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  nodejs_22,
  curl,
  docker-client,
  git,
  ripgrep,
  xdg-utils,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "ix";
  version = "0.14.0";

  # The release includes the CLI, native tree-sitter bindings, and Compass UI.
  src = fetchurl {
    url = "https://github.com/ix-infrastructure/Ix/releases/download/v${finalAttrs.version}/ix-${finalAttrs.version}-linux-amd64.tar.gz";
    hash = "sha256-4qYqYllnir0uyxjpxX3q15MMltn7ViebeLeOFclhO8E=";
  };

  strictDeps = true;
  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [stdenv.cc.cc.lib];

  dontConfigure = true;
  dontBuild = true;

  postUnpack = ''
    # npm packages also carry bindings for other architectures and OSes.
    find "$sourceRoot" -type d -path '*/prebuilds/*' ! -name linux-x64 \
      -prune -exec rm -rf {} +
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/ix" "$out/bin"
    cp -r cli core-ingestion compass "$out/lib/ix/"

    # Keep application files in the store, not in the writable IX_HOME state dir.
    substituteInPlace "$out/lib/ix/cli/dist/cli/commands/view.js" \
      --replace-fail 'join(ixHome(), "cli", "compass")' "\"$out/lib/ix/compass\""

    makeWrapper ${lib.getExe nodejs_22} "$out/bin/ix" \
      --add-flags "$out/lib/ix/cli/dist/cli/main.js" \
      --prefix PATH : ${lib.makeBinPath [curl docker-client git ripgrep xdg-utils]} \
      --set-default IX_NO_UPDATE_CHECK 1

    runHook postInstall
  '';

  meta = {
    description = "Persistent codebase knowledge graph for humans and AI agents";
    homepage = "https://github.com/ix-infrastructure/Ix";
    changelog = "https://github.com/ix-infrastructure/Ix/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "ix";
    platforms = ["x86_64-linux"];
    sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
  };
})
