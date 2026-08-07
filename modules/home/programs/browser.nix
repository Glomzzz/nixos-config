{pkgs, ...}: {
  home.packages = with pkgs; [
    firefox
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
