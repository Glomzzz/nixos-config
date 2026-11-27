# plannotator: visual plan and code review for coding agents, installed as
# `plannotator`, plus the self-hosted paste service as `plannotator-paste`.
# Upstream builds the CLI with `bun build --compile`, and the installer and npm
# launcher download these same release binaries, so Nix pins the GitHub release
# assets instead of building the Bun workspace.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  versionCheckHook,
  git,
  gh,
  jujutsu,
  xdg-utils,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "plannotator";
  version = "0.29.5";

  # Each asset is one Bun-compiled ELF binary. The hashes match the SHA256
  # sidecar files in the v0.29.4 release.
  src = fetchurl {
    url = "https://github.com/backnotprop/plannotator/releases/download/v${finalAttrs.version}/plannotator-linux-x64";
    hash = "sha256-Z8Lj2JMa5mwr7c+qpMZ+tz8WX8VdeDzdFHN8sTN5riI=";
  };

  pasteSrc = fetchurl {
    url = "https://github.com/backnotprop/plannotator/releases/download/v${finalAttrs.version}/plannotator-paste-linux-x64";
    hash = "sha256-vanUXy5t6JtEZGirTcSByvy0/rVTSUXIoskRhwcBSlg=";
  };

  strictDeps = true;
  dontUnpack = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  dontConfigure = true;
  dontBuild = true;
  # Stripping can remove the payload that Bun appends to the executable.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/plannotator"
    wrapProgram "$out/bin/plannotator" \
      --suffix PATH : ${lib.makeBinPath [git gh jujutsu xdg-utils]}
    install -Dm755 "$pasteSrc" "$out/bin/plannotator-paste"

    runHook postInstall
  '';

  nativeInstallCheckInputs = [versionCheckHook];
  doInstallCheck = true;

  meta = {
    description = "Visual plan and code review for coding agents, with annotations and one-click feedback";
    homepage = "https://plannotator.ai";
    changelog = "https://github.com/backnotprop/plannotator/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "plannotator";
    platforms = ["x86_64-linux"];
    sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
  };
})
