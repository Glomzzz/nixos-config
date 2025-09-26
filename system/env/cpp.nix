{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    clang-tools
    libgccjit
    cmake
    ninja
    clang
    valgrind
  ];
}
