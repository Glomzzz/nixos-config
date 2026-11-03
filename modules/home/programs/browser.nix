{pkgs, ...}: {
  home.packages = [
    # PDFs and EPUBs go to the system default (Emacs, see
    # modules/home/programs/emacs/integration.nix) instead of Firefox's PDF.js.
    (pkgs.firefox.override {
      extraPolicies = {
        DisableBuiltinPDFViewer = true;
        Handlers.mimeTypes."application/epub+zip" = {
          action = "useSystemDefault";
          ask = false;
        };
      };
    })
    # Secondary browser for sites that need Chrome; Firefox remains the default.
    pkgs.google-chrome
  ];

  home.sessionVariables = {
    BROWSER = "firefox";
  };
  xdg.mimeApps.defaultApplications = {
    "text/html" = ["firefox.desktop"];
    "x-scheme-handler/http" = ["firefox.desktop"];
    "x-scheme-handler/https" = ["firefox.desktop"];
  };
}
