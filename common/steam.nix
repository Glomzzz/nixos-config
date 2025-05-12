{... }: {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true; 
      dedicatedServer.openFirewall = true; 
      localNetworkGameTransfers.openFirewall = true; 
      fontPackages = with pkgs; [ source-han-sans ];
      extraPackages = with pkgs; [
        corefonts
        noto-fonts-cjk-sans
        source-han-sans
      ];
      extraCompatPackages = with pkgs; [
        pkgs.gamemode
        gamescope
        dxvk
        vkd3d
        mangohud
      ];
    }
}