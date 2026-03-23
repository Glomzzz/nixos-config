{pkgs, ...}: {
  home.packages = with pkgs; [
    glibc
    clang-tools
    libgccjit
    cmake
    ninja
    clang
    valgrind
    vcpkg
  ];
}
