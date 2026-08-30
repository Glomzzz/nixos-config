{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeBinaryWrapper,
  codex,
}:
buildNpmPackage rec {
  pname = "oh-my-codex";
  version = "0.21.0";

  src = fetchFromGitHub {
    owner = "Yeachan-Heo";
    repo = "oh-my-codex";
    tag = "v${version}";
    hash = "sha256-3Ec+EUQqdRGEeV03iK+IdGEXL2ZNzv+lUohMIy9EYdo=";
  };

  npmDepsHash = "sha256-4gElZ4IVeumFM3JgFTTxICnChM5FyQ1GzDONIjoMI8k=";

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
