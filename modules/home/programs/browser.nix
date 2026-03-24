{pkgs, ...}: {
  home.packages = with pkgs; let
    chromeBeta = callPackage ../../../pkgs/google-chrome-beta.nix {};
  in [
    chromeBeta
  ];

  home.sessionVariables = {
    BROWSER = "google-chrome-beta";
  };
  xdg.mimeApps.defaultApplications = {
    "text/html" = ["com.google.Chrome.beta.desktop"];
    "x-scheme-handler/http" = ["com.google.Chrome.beta.desktop"];
    "x-scheme-handler/https" = ["com.google.Chrome.beta.desktop"];
  };
}
