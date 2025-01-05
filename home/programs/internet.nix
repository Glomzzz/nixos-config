{
  pkgs,
  config,
  username,
  ...
}: {
  home.packages = with pkgs; [
    microsoft-edge
    (pkgs.callPackage ./qq { })
    (pkgs.callPackage ./clash-verge-rev { })
    wechat-uos
  ];
  
}
