{
  lib,
  buildNpmPackage,
  makeBinaryWrapper,
  nodejs,
  openviking-agent-plugins,
  pnpm,
}:
buildNpmPackage rec {
  pname = "deepseek-harness";
  version = "0.1.0-rc.8";

  src = ./deepseek-harness;

  npmDepsFetcherVersion = 2;
  npmDepsHash = "sha256-YBbZb/7E1dpzIxnwgyPVs3FrZMN+F4xNur6gK6QBX6w=";
  dontNpmBuild = true;

  nativeBuildInputs = [makeBinaryWrapper];

  postInstall = ''
    packageRoot="$out/lib/node_modules/deepseek-harness-nix"
    substituteInPlace "$packageRoot/bootstrap.mjs" \
      --replace-fail '@PACKAGE_ROOT@' "$packageRoot"
    substituteInPlace "$packageRoot/node_modules/openviking-dsh-nix/cordis.patch.yml" \
      --replace-fail '@OPENVIKING_PROXY@' '${openviking-agent-plugins}/bin/openviking-mcp-proxy' \
      --replace-fail '@OPENVIKING_SKILLS@' '${openviking-agent-plugins}/share/openviking/agent-plugins/skills'
    makeBinaryWrapper ${nodejs}/bin/node "$out/bin/dsh" \
      --add-flags '--expose-internals' \
      --add-flags "$packageRoot/bootstrap.mjs" \
      --prefix PATH : ${lib.makeBinPath [pnpm]}
    makeBinaryWrapper ${nodejs}/bin/node "$out/bin/modlens" \
      --add-flags "$packageRoot/node_modules/@liustack/modlens/dist/main.js"
    makeBinaryWrapper ${nodejs}/bin/node "$out/bin/modsearch" \
      --add-flags "$packageRoot/node_modules/@liustack/modsearch/dist/main.js"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test "$($out/bin/dsh --version)" = "${version}"
    test "$($out/bin/modlens --version)" = "3.22.1"
    test "$($out/bin/modsearch --version)" = "5.8.0"
    checkHome="$TMPDIR/dsh-home"
    DSH_HOME="$checkHome" "$out/bin/dsh" web --dump-config > "$TMPDIR/dsh-config.yml"
    grep -q "name: '@liustack/modlens'" "$TMPDIR/dsh-config.yml"
    grep -q "name: '@liustack/modsearch'" "$TMPDIR/dsh-config.yml"
    grep -q 'name: dsh-routing-suite' "$TMPDIR/dsh-config.yml"
    grep -q '# == openviking-dsh-nix' "$TMPDIR/dsh-config.yml"
    grep -q "name: '@deepseek-ai/dsh-mcp-client'" "$TMPDIR/dsh-config.yml"
    grep -q "name: '@deepseek-ai/dsh-skill-filesystem'" "$TMPDIR/dsh-config.yml"
    grep -q '${openviking-agent-plugins}/bin/openviking-mcp-proxy' "$TMPDIR/dsh-config.yml"
    runHook postInstallCheck
  '';

  meta = {
    description = "DeepSeek Harness CLI with ModLens, ModSearch, routing, and OpenViking integration";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    mainProgram = "dsh";
    platforms = lib.platforms.unix;
  };
}
