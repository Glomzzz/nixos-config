{pkgs, ...}: {
  home.packages = with pkgs; [
    codex
    oh-my-codex
  ];
}
