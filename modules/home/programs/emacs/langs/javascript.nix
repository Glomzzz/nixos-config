{pkgs, ...}: {
  home.packages = with pkgs; [
    nodejs
    pnpm
    bun
    deno
    typescript
    typescript-language-server
    prettier
    vscode-js-debug
    vscode-langservers-extracted
  ];
}
