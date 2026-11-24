final: _prev: {
  cherry-studio = final.callPackage ./cherry-studio.nix {};
  cherry-studio-with-desktop = final.callPackage ./cherry-studio-with-desktop.nix {};
  chinese-word-segmentation = final.callPackage ./chinese-word-segmentation.nix {};
  clipferry = final.callPackage ./clipferry.nix {};
  bun = final.callPackage ./bun.nix {};
  fff-emacs-helper = final.callPackage ./fff-emacs-helper.nix {};
  ix = final.callPackage ./ix.nix {};
  jujutsu = final.callPackage ./jujutsu.nix {};
  logisim-evolution = final.callPackage ./logisim-evolution {};
  mandible = final.callPackage ./mandible.nix {};
  phono-core = final.callPackage ./phono-core.nix {};
  phono-fcitx5-addon = final.callPackage ./phono-fcitx5-addon.nix {};
  plannotator = final.callPackage ./plannotator.nix {};
  ssh-proxy-mac-mini = final.callPackage ./ssh-proxy-mac-mini.nix {};
  wechat = final.callPackage ./wechat {};
  wivrn = final.callPackage ./wivrn.nix {};
  zotero = final.callPackage ./zotero {};
}
