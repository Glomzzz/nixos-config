_: {
  imports = [
    ../../modules/home
  ];

  # Preserve the already-adopted compatibility baseline across input updates.
  # This is not Home Manager's release version; see docs/state-version.md.
  home.stateVersion = "26.11";
  home.enableNixpkgsReleaseCheck = false;
}
