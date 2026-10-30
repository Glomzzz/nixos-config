{
  lib,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    gnumake
    clang-tools
    # Wrapped GCC supplies headers, startup objects, and the linker setup.
    # Emacs already closes over libgccjit; exposing its bin/ shadows gcc.
    # Clang owns generic cc/c++ names; gcc/g++ remain available explicitly.
    (lib.setPrio 20 gcc)
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
