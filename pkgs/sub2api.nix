{
  lib,
  stdenvNoCC,
  fetchurl,
  gnutar,
  system,
}: let
  version = "0.1.104";
  sources = {
    "x86_64-linux" = {
      url = "https://github.com/Wei-Shaw/sub2api/releases/download/v${version}/sub2api_${version}_linux_amd64.tar.gz";
      sha256 = "sha256-JGqb++t13WpTGzFRYzLBYWsRZrs8JDtgECuKjQ54GKk=";
    };
    "aarch64-linux" = {
      url = "https://github.com/Wei-Shaw/sub2api/releases/download/v${version}/sub2api_${version}_linux_arm64.tar.gz";
      sha256 = "sha256-ijhRLHdD9DK7t6KEDU3My9y0fhKvgawT166gWuXx42A=";
    };
  };
  source = lib.attrByPath [system] null sources;
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
