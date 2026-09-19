{
  lib,
  rustPlatform,
  fetchFromGitHub,
  git,
  installShellFiles,
  versionCheckHook,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "mandible";
  version = "0.8.0";

  src = fetchFromGitHub {
    owner = "AS-FOSS";
    repo = "mandible";
    tag = "v${finalAttrs.version}";
    hash = "sha256-NUiZedFJu8su9qILNRAQuVJ+K+Q5ezuLS3iU9t2ZrHE=";
  };

  cargoHash = "sha256-lQmObuihaB9TFwTSLDXSvUf/YsiZj+HQKuWTyNqkEis=";

  nativeBuildInputs = [installShellFiles];
  nativeCheckInputs = [git];

  cargoBuildFlags = [
    "--package"
    "mandible"
  ];
  cargoTestFlags = [
    "--package"
    "mandible"
  ];

  postInstall = ''
    installManPage packaging/mandible.1

    mandibleBin="$(find target -type f -path '*/release/mandible' -print -quit)"
    test -n "$mandibleBin"
    completionDir="$TMPDIR/mandible-completions"
    mkdir -p "$completionDir"
    "$mandibleBin" --completions bash > "$completionDir/mandible.bash"
    "$mandibleBin" --completions fish > "$completionDir/mandible.fish"
    "$mandibleBin" --completions zsh > "$completionDir/_mandible"
    installShellCompletion --cmd mandible \
      --bash "$completionDir/mandible.bash" \
      --fish "$completionDir/mandible.fish" \
      --zsh "$completionDir/_mandible"
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [versionCheckHook];

  meta = {
    description = "TUI manual viewer for command-line tools";
    homepage = "https://github.com/AS-FOSS/mandible";
    changelog = "https://github.com/AS-FOSS/mandible/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = with lib.licenses; [
      asl20
      mit
    ];
    mainProgram = "mandible";
    platforms = lib.platforms.unix;
  };
})
