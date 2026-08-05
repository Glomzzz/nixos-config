{pkgs, ...}: {
  home.packages = with pkgs; [
    biome
    bun
    deno
    eslint
    nodejs
    pnpm
    prettier
    typescript
    typescript-language-server
    vscode-langservers-extracted
  ];
}
