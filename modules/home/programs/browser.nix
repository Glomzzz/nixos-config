{pkgs, ...}: {
  home.packages = with pkgs; let
    chromeBeta = callPackage ./google-chrome-beta.nix {};
  in [
    chromeBeta
  ];

  home.sessionVariables = {
    BROWSER = "google-chrome-beta";
  };
}
