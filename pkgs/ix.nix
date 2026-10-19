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
  version = "0.13.0";

  # The release includes the CLI, native tree-sitter bindings, and Compass UI.
  src = fetchurl {
    url = "https://github.com/ix-infrastructure/Ix/releases/download/v${finalAttrs.version}/ix-${finalAttrs.version}-linux-amd64.tar.gz";
    hash = "sha256-KaHXh1N/S5N/IAqslpTD/Xq3L8udzXBnlskfwOR7LN0=";
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
      --replace-fail 'join(IX_HOME, "cli", "compass")' "\"$out/lib/ix/compass\""

    makeWrapper ${lib.getExe nodejs_22} "$out/bin/ix" \
      --add-flags "$out/lib/ix/cli/dist/cli/main.js" \
      --prefix PATH : ${lib.makeBinPath [curl docker-client git ripgrep xdg-utils]} \
      --set-default IX_NO_UPDATE_CHECK 1

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    export HOME="$TMPDIR/ix-home"
    export IX_HOME="$HOME/.ix"
    mkdir -p "$HOME"
    test "$("$out/bin/ix" --version)" = "${finalAttrs.version}"
    "$out/bin/ix" --help > /dev/null
    test -s "$out/lib/ix/cli/dist/docker-compose.standalone.yml"
    test -s "$out/lib/ix/compass/index.html"
    test -s "$out/lib/ix/compass/.version"

    # --version does not load the native parser; exercise it after patchelf.
    ${lib.getExe nodejs_22} --input-type=module <<EOF
    import assert from 'node:assert/strict';
    import { parseFile, isGrammarSupported } from '$out/lib/ix/core-ingestion/dist/index.js';
    await import('$out/lib/ix/core-ingestion/dist/patch-builder.js');
    for (const extension of [
      'js', 'ts', 'py', 'java', 'c', 'cpp', 'cs', 'go', 'rb', 'rs', 'php',
      'kt', 'swift', 'scala', 'r', 'sas', 'ex', 'mk', 'lua', 'sh', 'ps1',
      'hs', 'zig', 'html', 'xml', 'tf', 'css',
    ]) {
      assert.ok(isGrammarSupported('smoke.' + extension), 'Missing grammar: ' + extension);
    }
    for (const [file, source] of [
      ['smoke.ts', 'export function smoke() { return 1; }'],
      ['smoke.py', 'def smoke():\n    return 1\n'],
      ['smoke.rs', 'pub fn smoke() -> i32 { 1 }'],
    ]) {
      const result = parseFile(file, source);
      assert.ok(result?.entities.some(entity => entity.name === 'smoke'), file);
    }
    EOF

    runHook postInstallCheck
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
