{pkgs, ...}: {
  home.packages = with pkgs.haskellPackages; [
    ghc
    stack
    haskell-language-server
    ormolu
  ];
}
