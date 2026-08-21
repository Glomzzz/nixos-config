{
  lib,
  stdenv,
  fetchurl,
  installShellFiles,
  makeBinaryWrapper,
  ripgrep,
  bubblewrap,
  versionCheckHook,
  installShellCompletions ? stdenv.buildPlatform.canExecute stdenv.hostPlatform,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "codex";
  version = "0.149.0";

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${finalAttrs.version}/codex-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-c2iyBV7QIVf+omlbufWvPuew5AxaO+vIHfxZZwQkTP0=";
  };

  # Out-of-process V8 execution companion binary. Codex spawns this at
  # runtime; without it, Code Mode fails closed.
  codeModeHostSrc = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${finalAttrs.version}/codex-code-mode-host-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-NgCkWsKwn+PJlfT0mGATH+o4i0bECcgqAmb8TQNCoEw=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    installShellFiles
    makeBinaryWrapper
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp codex-x86_64-unknown-linux-musl $out/bin/codex
    chmod +x $out/bin/codex
    tar xzf ${finalAttrs.codeModeHostSrc}
    cp codex-code-mode-host-x86_64-unknown-linux-musl $out/bin/codex-code-mode-host
    chmod +x $out/bin/codex-code-mode-host
    runHook postInstall
  '';

  postInstall = lib.optionalString installShellCompletions ''
    installShellCompletion --cmd codex \
      --bash <($out/bin/codex completion bash) \
      --fish <($out/bin/codex completion fish) \
      --zsh <($out/bin/codex completion zsh)
  '';

  postFixup = ''
    wrapProgram $out/bin/codex --prefix PATH : ${
      lib.makeBinPath ([ripgrep] ++ lib.optionals stdenv.hostPlatform.isLinux [bubblewrap])
    }
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [versionCheckHook];

  meta = {
    description = "Lightweight coding agent that runs in your terminal";
    homepage = "https://github.com/openai/codex";
    changelog = "https://raw.githubusercontent.com/openai/codex/refs/tags/rust-v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = ["x86_64-linux"];
    sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
  };
})
