{pkgs, ...}: {
  home.packages = with pkgs; [
    nodejs
    pnpm
    bun
    typescript-language-server
    vscode-langservers-extracted
  ];
}
