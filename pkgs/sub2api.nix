{
  lib,
  stdenvNoCC,
  fetchurl,
  gnutar,
}: let
  version = "0.1.169";
  inherit (stdenvNoCC.hostPlatform) system;
  sources = {
    "x86_64-linux" = {
      url = "https://github.com/Wei-Shaw/sub2api/releases/download/v${version}/sub2api_${version}_linux_amd64.tar.gz";
      sha256 = "sha256-Rcq3CcV4IIsJ68rBoc+aao1qgbmZRipxO1jO4yuFOUY=";
    };
    "aarch64-linux" = {
      url = "https://github.com/Wei-Shaw/sub2api/releases/download/v${version}/sub2api_${version}_linux_arm64.tar.gz";
      sha256 = "sha256-NmRSSGUVCq/kkqDpu+x0+0sEKvAk1HKYtyHOL4jNroo=";
    };
  };
  source = sources.${system} or (throw "Unsupported system: ${system}");
in
  stdenvNoCC.mkDerivation {
    pname = "sub2api";
    inherit version;

    src = fetchurl source;
    nativeBuildInputs = [gnutar];
    dontUnpack = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin"
      tar -xzf "$src"
      install -m755 sub2api "$out/bin/sub2api"
      runHook postInstall
    '';

    meta = {
      description = "Sub2API binary package";
      homepage = "https://github.com/Wei-Shaw/sub2api";
      license = lib.licenses.unfreeRedistributable;
      platforms = builtins.attrNames sources;
      mainProgram = "sub2api";
    };
  }
