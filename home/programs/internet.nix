{
  pkgs,
  config,
  username,
  ...
}: {
  home.packages = with pkgs; [
    microsoft-edge
    qq
    clash-verge-rev
    wechat-uos
  ];
  
}