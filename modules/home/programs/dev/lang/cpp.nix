{ pkgs, ... }:
{
  home.packages = with pkgs; [
    gnumake
    glibc
    clang-tools
    libgccjit
    cmake
    ninja
    clang
    valgrind
    vcpkg
    pkg-config
  ];
}
