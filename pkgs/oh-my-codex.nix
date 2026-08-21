{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeBinaryWrapper,
  codex,
}:
buildNpmPackage rec {
  pname = "oh-my-codex";
  version = "0.20.5";

  src = fetchFromGitHub {
    owner = "Yeachan-Heo";
    repo = "oh-my-codex";
    tag = "v${version}";
    hash = "sha256-k5K6cZ3eSSmxfyi2VaUGXNNNNFOIQwdP4GpNpR+Xksc=";
  };

  npmDepsHash = "sha256-sEx7diplbNet1UfHeT3EddkuniVaebF1NSo8QcBnOuM=";

  nativeBuildInputs = [
    makeBinaryWrapper
  ];

  npmBuildScript = "build";

  postInstall = ''
    wrapProgram $out/bin/omx --prefix PATH : ${lib.makeBinPath [codex]}
  '';

  meta = {
    description = "Multi-agent orchestration layer for OpenAI Codex CLI";
    homepage = "https://github.com/Yeachan-Heo/oh-my-codex";
    license = lib.licenses.mit;
    mainProgram = "omx";
    platforms = lib.platforms.unix;
  };
}
