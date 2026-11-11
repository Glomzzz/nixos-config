{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  installShellFiles,
  buildPackages,
  nix-update-script,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "jujutsu";
  version = "0.47.1";

  src = fetchFromGitHub {
    owner = "jj-vcs";
    repo = "jj";
    tag = "v${finalAttrs.version}";
    hash = "sha256-vyV2QpOlCnr8WUijJYYx7oVhMhEy+jRJxXe9rRBlowA=";
  };

  cargoHash = "sha256-1lJwKpI1NE3Q7RgEgWkdITHj7nt4WRLk9fC5yWndJKs=";

  nativeBuildInputs = [installShellFiles];

  doCheck = false;

  cargoBuildFlags = [
    # Don't install the gen-protos build tool.
    "--bin"
    "jj"
  ];

  env = {
    # Disable vendored libraries.
    ZSTD_SYS_USE_PKG_CONFIG = "1";
    LIBGIT2_NO_VENDOR = "1";
    LIBSSH2_SYS_USE_PKG_CONFIG = "1";
  };

  postInstall = let
    jj = "${stdenv.hostPlatform.emulator buildPackages} $out/bin/jj";
  in
    lib.optionalString (stdenv.hostPlatform.emulatorAvailable buildPackages) ''
      mkdir -p $out/share/man
      ${jj} util install-man-pages $out/share/man/

      installShellCompletion --cmd jj \
        --bash <(COMPLETE=bash ${jj}) \
        --fish <(COMPLETE=fish ${jj}) \
        --nushell <(${jj} util completion nushell) \
        --zsh <(COMPLETE=zsh ${jj})
    '';

  passthru.updateScript = nix-update-script {};

  meta = {
    description = "Git-compatible DVCS that is both simple and powerful";
    homepage = "https://jj-vcs.dev/";
    changelog = "https://github.com/jj-vcs/jj/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.asl20;
    mainProgram = "jj";
  };
})
