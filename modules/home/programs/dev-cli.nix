{pkgs, ...}: {
  home.packages = with pkgs; [
    docker-compose
    kubectl
    nodePackages.npm
    nodePackages.pnpm
    bun
    dbeaver-bin
    mycli
    pgcli
  ];
}
