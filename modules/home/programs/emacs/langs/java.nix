{pkgs, ...}: {
  home.packages = with pkgs; [
    # GraalVM's native-image install check segfaults with the nixpkgs revision
    # pinned in flake.lock, so use the plain JDK jdt-language-server runs on.
    jdk25
    jdt-language-server # Java LSP
  ];

  # Open Java sources in Emacs.
  xdg.mimeApps.defaultApplications = {
    "text/x-java" = ["emacsclient.desktop"];
  };
}
