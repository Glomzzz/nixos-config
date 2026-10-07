final: _prev: {
  cherry-studio = final.callPackage ./cherry-studio.nix {};
  cherry-studio-with-desktop = final.callPackage ./cherry-studio-with-desktop.nix {};
  clipferry = final.callPackage ./clipferry.nix {};
  bun = final.callPackage ./bun.nix {};
  mandible = final.callPackage ./mandible.nix {};
  ssh-proxy-mac-mini = final.callPackage ./ssh-proxy-mac-mini.nix {};
  v2raya-assets = final.callPackage ./v2raya-assets.nix {};
  wechat = final.callPackage ./wechat {};
  wivrn = final.callPackage ./wivrn.nix {};
}
