{ pkgs, ...} :{
    # imports = [
    #   ./alacritty.nix
    # ];
    users.users.glom = {
      isNormalUser = true;
      description = "Glom Zhao";
      extraGroups = [ "networkmanager" "wheel" ];
      packages = with pkgs; [
        
      ];
    };
    # home-manager.users.glom = {
    #   xdg.mimeApps = {
    #     enable = true;
    #     defaultApplications = {
    #       cmd = "${pkgs.alacritty}/bin/alacritty";
    #       desktop = "alacritty";
    #     };
    #   };
    #   home.stateVersion = "24.05";
    # };
}