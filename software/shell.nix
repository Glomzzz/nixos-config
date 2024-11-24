{ config,pkgs, ...} : {


  config = {
    environment.systemPackages = with pkgs; [
      alacritty
      warp-terminal
    ];
  };
}
