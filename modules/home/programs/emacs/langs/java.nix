{pkgs, ...}: {
  home.packages = with pkgs; [
    graalvmPackages.graalvm-oracle
    jdt-language-server # Java LSP
  ];

  # Open Java sources in Emacs.
  xdg.mimeApps.defaultApplications = {
    "text/x-java" = ["emacsclient.desktop"];
  };
}
