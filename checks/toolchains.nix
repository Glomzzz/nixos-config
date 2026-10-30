{
  pkgs,
  hostPkgs,
  config,
}: let
  home = config.home-manager.users.glom;
  gcc = pkgs.lib.setPrio 20 hostPkgs.gcc;
  profile = pkgs.buildEnv {
    name = "tested-c-cpp-toolchain-profile";
    paths = [gcc hostPkgs.clang];
    pathsToLink = ["/bin"];
  };
  libraries = config.programs.nix-ld.libraries;
  explicitPackages = config.environment.systemPackages ++ home.home.packages;
  module = import ../modules/nixos/programs/nix-ld.nix {inherit pkgs;};
in
  assert !(module ? environment.systemPackages);
  assert builtins.elem gcc home.home.packages;
  assert !(builtins.elem hostPkgs.libgccjit explicitPackages);
  assert builtins.elem hostPkgs.stdenv.cc.cc libraries;
  assert config.environment.sessionVariables.NIX_LD_LIBRARY_PATH == "/run/current-system/sw/share/nix-ld/lib";
    pkgs.runCommand "wrapped-toolchain-check"
    {nativeBuildInputs = [profile];}
    ''
      printf '#include <stdio.h>\nint main(void) { puts("C toolchain works"); return 0; }\n' > test.c
      gcc -Wall -Wextra -Werror test.c -o test-c
      ./test-c
      printf '#include <iostream>\nint main() { std::cout << "C++ toolchain works\\n"; }\n' > test.cpp
      g++ -Wall -Wextra -Werror test.cpp -o test-cpp
      ./test-cpp
      cc -Wall -Wextra -Werror test.c -o test-cc
      ./test-cc
      c++ -Wall -Wextra -Werror test.cpp -o test-cxx
      ./test-cxx
      touch "$out"
    ''
