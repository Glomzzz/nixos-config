{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:
rustPlatform.buildRustPackage rec {
  pname = "clipferry";
  version = "0.0.3";

  src = fetchFromGitHub {
    owner = "jmylchreest";
    repo = "clipferry";
    tag = "v${version}";
    hash = "sha256-xtEYOqIjNRNnaLThngo63/kSIAkQWYjqaSsrx3TsyNs=";
  };

  cargoHash = "sha256-Lw7b1c75hXz+tS5Yp6B0CInJIyPyRYJykGQ1yV5eldI=";

  # Upstream's unit and sandbox tests do not need a running desktop.
  doCheck = true;

  meta = {
    description = "Event-driven X11 and Wayland clipboard bridge";
    homepage = "https://github.com/jmylchreest/clipferry";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "clipferry";
  };
}
