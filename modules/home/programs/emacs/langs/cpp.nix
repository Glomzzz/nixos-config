{pkgs, ...}: {
  home.packages = with pkgs; [
    gnumake
    glibc
    clang-tools
    libgccjit
    cmake
    ninja
    clang
    gdb
    valgrind
    vcpkg
    pkg-config
  ];

  # Open C/C++ sources in Emacs.
  xdg.mimeApps.defaultApplications = {
    "text/x-c" = ["emacsclient.desktop"];
    "text/x-c++" = ["emacsclient.desktop"];
    "text/x-c++hdr" = ["emacsclient.desktop"];
    "text/x-c++src" = ["emacsclient.desktop"];
    "text/x-chdr" = ["emacsclient.desktop"];
    "text/x-csrc" = ["emacsclient.desktop"];
  };
}
