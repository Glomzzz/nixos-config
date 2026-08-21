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
  version = "0.3.2";

  src = fetchFromGitHub {
    owner = "AS-FOSS";
    repo = "mandible";
    tag = "v${finalAttrs.version}";
    hash = "sha256-U7SApBvuELkN4f9uhLdcThO09UphCiHR6ez0bKQE71Q=";
  };

  cargoHash = "sha256-8sqi/SPOEdpYTxw2M9TFmnFlNInLYDVLmD7w/TEO8lY=";

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

    completionDir="$(find target -type d -path '*/release/build/mandible-*/out' -print -quit)"
    test -n "$completionDir"
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
