{pkgs, ...}: {
  # The interpreter brings its standard library, `pip` and `venv`, so throwaway
  # environments use plain PyPI rather than a Nix derivation per project.
  home.packages = [pkgs.python3];
}
