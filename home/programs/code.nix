{ pkgs, ... }:
{
  home.packages = with pkgs; [
    zed-editor
    opencode
    claude-code
    codex
    antigravity
    vscode
    nixpkgs-fmt
    jetbrains-toolbox
    # Minecraft Mono Font
    monocraft
    # Nix LSP
    nil
    nixd
    # Sandbox
    bubblewrap
  ];
}
