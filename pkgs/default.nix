final: _prev: {
  cherry-studio = final.callPackage ./cherry-studio.nix {};
  cherry-studio-with-desktop = final.callPackage ./cherry-studio-with-desktop.nix {};
  codex = final.callPackage ./codex.nix {};
  # google-chrome-beta = final.callPackage ./google-chrome-beta.nix {};
  nu_scripts = final.callPackage ./nu-scripts.nix {};
  oh-my-codex = final.callPackage ./oh-my-codex.nix {};
  ssh-proxy-mac-mini = final.callPackage ./ssh-proxy-mac-mini.nix {};
  v2raya-assets = final.callPackage ./v2raya-assets.nix {};
  wechat = final.callPackage ./wechat {};
}
