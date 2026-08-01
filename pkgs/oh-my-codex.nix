{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeBinaryWrapper,
  codex,
}:
buildNpmPackage rec {
  pname = "oh-my-codex";
  version = "0.20.4";

  src = fetchFromGitHub {
    owner = "Yeachan-Heo";
    repo = "oh-my-codex";
    tag = "v${version}";
    hash = "sha256-ZSURmV3LQeuSjQqyRhWCAhQ+m0oJSiba7tdUDc7RsBg=";
  };

  npmDepsHash = "sha256-5zCwlRqjcH8wYqPSGpI32w9YA3Y9V7BJL7QBzG6Jw9o=";

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
