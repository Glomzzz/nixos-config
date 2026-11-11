{
  lib,
  rustPlatform,
  fetchFromGitHub,
  installShellFiles,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "mandible";
  version = "0.9.0";

  src = fetchFromGitHub {
    owner = "AS-FOSS";
    repo = "mandible";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Eo2vwSiopyZyhARo8dIKgQuchWQ4q1gSYahhf0KqJS4=";
  };

  cargoHash = "sha256-H4uKnj6C+Ly6R8SjccdER/hlxuvFOqEgMrDRk3cFdb4=";

  nativeBuildInputs = [installShellFiles];

  doCheck = false;

  cargoBuildFlags = [
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
