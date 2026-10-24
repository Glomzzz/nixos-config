{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:
stdenv.mkDerivation rec {
  pname = "phono-core";
  version = "0.1.1";

  # Use the release SDK pinned by phono-fcitx5-addon's ci/core-sdk.json.
  # It contains the self-contained ExecuTorch runtime and dependency notices.
  src = fetchurl {
    url = "https://github.com/phono-project/phono-core/releases/download/v${version}/phono-core-sdk-${version}-linux-x86_64.tar.gz";
    hash = "sha256-zOHMrf9n0Z3E81vJrf8Hk+c00InelgFacJKGxRKEx70=";
  };

  sourceRoot = ".";
  nativeBuildInputs = [autoPatchelfHook];
  buildInputs = [stdenv.cc.cc.lib];
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r include lib share "$out/"
    runHook postInstall
  '';

  meta = {
    description = "Phono on-device Pinyin inference runtime and C ABI SDK";
    homepage = "https://github.com/phono-project/phono-core";
    license = lib.licenses.apache20;
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    platforms = ["x86_64-linux"];
  };
}
