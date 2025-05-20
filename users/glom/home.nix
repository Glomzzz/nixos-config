{pkgs,  ...}: {
  ##################################################################################################################
  #
  # All Glom's Home Manager Configuration
  #
  ##################################################################################################################

  imports = [
    ../../home
  ];

  home.packages = with pkgs; [
      kdePackages.kwallet-pam
      poppler_data
  ];
  home.enableNixpkgsReleaseCheck = false;



}
