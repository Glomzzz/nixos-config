{...}: {
  imports = [
    ../../../system/locale.nix
    ../../../system/font.nix
    ./networking.nix
    ../../../system/env/cpp.nix
    ../../../system/env/java.nix
    ../../../system/env/rust.nix
    ../../../system/env/other.nix
    ./home-manager.nix
  ];
}
