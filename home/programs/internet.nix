{
  pkgs,
  config,
  username,
  ...
}: {
  home.packages = with pkgs; [
    microsoft-edge
    ./qq
  ];
  
}
