{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
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
