{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  libgit2,
  openssl,
  zlib,
}: let
  # Upstream has no releases.  The pin must match the commit that the Emacs
  # package declares in `modules/feat/workspace/fff.el' of ~/.config/emacs:
  # the helper's JSON Lines protocol is the contract between the two.
  src = fetchFromGitHub {
    owner = "Cbeck527";
    repo = "fff-emacs";
    rev = "4d00123b738fa6c4493f6e89e3eb916278c910b4";
    hash = "sha256-VxpO1qWMRXvsm851O+TZu9HkJHH7wk6GnIGcAkw2Chg=";
  };
in
  rustPlatform.buildRustPackage {
    pname = "fff-emacs-helper";
    version = "0.1.0-unstable-2026-05-05";

    inherit src;
    cargoLock.lockFile = "${src}/Cargo.lock";

    # fff-search links libgit2 for repository status and history.
    nativeBuildInputs = [pkg-config];
    buildInputs = [libgit2 openssl zlib];

    # The helper caches frecency data under $XDG_CACHE_HOME.  The sandbox HOME
    # is not writable, so give the unit tests a scratch cache.
    preCheck = ''
      export XDG_CACHE_HOME=$TMPDIR/cache
    '';

    meta = {
      description = "Long-lived fff file search helper for Emacs (JSON Lines over stdio)";
      homepage = "https://github.com/Cbeck527/fff-emacs";
      license = lib.licenses.mit;
      mainProgram = "fff-emacs-helper";
      platforms = lib.platforms.unix;
    };
  }
