{pkgs,username, ...}:{
  ##################################################################################################################
  #
  # NixOS Configuration
  #
  ##################################################################################################################
  imports = [
    ../../common/nix-ld.nix
  ];
  # To make sure that the home-manager session variables are loaded
  # https://github.com/nix-community/home-manager/issues/1011 
  environment.extraInit = let 
      homeManagerSessionVars = "/etc/profiles/per-user/${username}/etc/profile.d/hm-session-vars.sh";
    in "[[ -f ${homeManagerSessionVars} ]] && source ${homeManagerSessionVars}";
}