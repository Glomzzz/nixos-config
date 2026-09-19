{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  unzip,
  openssl,
  installShellFiles,
  versionCheckHook,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "bun";
  version = "1.4.2";

  src = fetchurl {
    url = "https://github.com/oven-sh/bun/releases/download/bun-v${finalAttrs.version}/bun-linux-x64-baseline.zip";
    hash = "sha256-xngEDxT+BEDrg503y9DOTAUaMtpygGrJfeamqra/co8=";
  };

  strictDeps = true;
  nativeBuildInputs = [
    autoPatchelfHook
    installShellFiles
    unzip
  ];
  buildInputs = [openssl];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 ./bun $out/bin/bun
    ln -s $out/bin/bun $out/bin/bunx
    runHook postInstall
  '';

  postPhases = ["postPatchelf"];
  postPatchelf = ''
    installShellCompletion --cmd bun \
      --bash <(SHELL="bash" $out/bin/bun completions) \
      --zsh <(SHELL="zsh" $out/bin/bun completions) \
      --fish <(SHELL="fish" $out/bin/bun completions)
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [versionCheckHook];
  versionCheckProgramArg = "--version";

  meta = {
    description = "Incredibly fast JavaScript runtime, bundler, transpiler and package manager";
    homepage = "https://bun.sh";
    changelog = "https://bun.sh/blog/bun-v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      lgpl21Only
    ];
    mainProgram = "bun";
    platforms = ["x86_64-linux"];
    sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
  };
})
