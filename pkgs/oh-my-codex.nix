{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeBinaryWrapper,
  codex,
}:
buildNpmPackage rec {
  pname = "oh-my-codex";
  version = "0.15.2";

  src = fetchFromGitHub {
    owner = "Yeachan-Heo";
    repo = "oh-my-codex";
    tag = "v${version}";
    hash = "sha256-KYRNVv+0L+7v6VvPVo4Vdi9ALcvAH/7WTgxn5Y8cncE=";
  };

  npmDepsHash = "sha256-Zf/nYTFclUQqxEFJVmZY5lie9htVWLov7BdyY9EtnV0=";

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
