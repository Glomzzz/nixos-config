{pkgs, ...}: {
  home.packages = with pkgs; [
    google-chrome
  ];

  home.sessionVariables = {
    BROWSER = "google-chrome";
  };
  xdg.mimeApps.defaultApplications = {
    "text/html" = ["com.google.Chrome.desktop"];
    "x-scheme-handler/http" = ["com.google.Chrome.desktop"];
    "x-scheme-handler/https" = ["com.google.Chrome.desktop"];
  };
}
