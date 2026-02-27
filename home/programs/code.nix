{pkgs, ...}: {
  home.packages = with pkgs; [
    opencode
    antigravity
    vscode
    nixpkgs-fmt
    jetbrains-toolbox
  ];
}

