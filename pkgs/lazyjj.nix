{
  lib,
  rustPlatform,
  fetchFromGitHub,
  makeWrapper,
  jujutsu,
  nix-update-script,
  versionCheckHook,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "lazyjj";
  version = "0.6.1";

  src = fetchFromGitHub {
    owner = "Cretezy";
    repo = "lazyjj";
    tag = "v${finalAttrs.version}";
    hash = "sha256-xpRuXefP2agcZojvAUvODDOFJoEyTiMztJM3VNCeryA=";
  };

  cargoHash = "sha256-LLbMR3FT5Ci7A9TlhRtU0rpMilXZXb4DH85/R776OQY=";

  # Upstream only exposes log-tab keybindings; patch the remaining input contexts.
  patches = [../patches/lazyjj-emacs-keymap.patch];

  nativeBuildInputs = [makeWrapper];
  nativeCheckInputs = [jujutsu];

  checkFlags = [
    # Upstream's snapshot predates changes to jj diff output (also skipped in nixpkgs).
    "--skip=commander::files::tests::get_file_diff"
  ];

  postInstall = ''
    wrapProgram $out/bin/lazyjj \
      --prefix PATH : ${lib.makeBinPath [jujutsu]}
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [versionCheckHook];

  passthru.updateScript = nix-update-script {};

  meta = {
    description = "TUI for Jujutsu/jj";
    homepage = "https://github.com/Cretezy/lazyjj";
    changelog = "https://github.com/Cretezy/lazyjj/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "lazyjj";
  };
})
