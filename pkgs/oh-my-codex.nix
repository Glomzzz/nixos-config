{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeBinaryWrapper,
  codex,
}:
buildNpmPackage rec {
  pname = "oh-my-codex";
  version = "0.18.13";

  src = fetchFromGitHub {
    owner = "Yeachan-Heo";
    repo = "oh-my-codex";
    tag = "v${version}";
    hash = "sha256-1zQBKBspNl2UwXgc3lP8QphXAJD0ooRrPgbyd0JTO8A=";
  };

  npmDepsHash = "sha256-7l/wPoSWxQBVaF6VBdTSrmFHOzUJv1QVa27ptf8/52k=";

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
