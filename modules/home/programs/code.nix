{pkgs, ...}: {
  home.packages = with pkgs; [
    zed-editor
    opencode
    claude-code
    codex
    antigravity
    vscode
    nixpkgs-fmt
    jetbrains-toolbox
    monocraft
    nil
    nixd
    bubblewrap
  ];
}
