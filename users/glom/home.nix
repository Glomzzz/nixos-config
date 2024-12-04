{pkgs, username, ...}: {
  ##################################################################################################################
  #
  # All Glom's Home Manager Configuration
  #
  ##################################################################################################################

  imports = [
    ../../home
  ];

  home.packages = with pkgs; [
      sony-headphones-client
      spotify
      vscode
      zotero
      obsidian
      v2raya
      telegram-desktop
      kwallet-pam
  ];
  home.enableNixpkgsReleaseCheck = false;

  programs.obs-studio.enable = true;
  programs.git = {
    userName = "Glom Zhao";
    userEmail = "glom@skillw.com";
  };

}
