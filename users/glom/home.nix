{inputs, ...}: {
  ##################################################################################################################
  #
  # All Glom's Home Manager Configuration
  #
  ##################################################################################################################

  imports = [
    inputs.nix-openclaw.homeManagerModules.openclaw
    ../../modules/home
  ];

  home.enableNixpkgsReleaseCheck = false;
}
