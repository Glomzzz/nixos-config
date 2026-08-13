{
  lib,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    (lib.hiPrio rust-analyzer)
    rustup
    trunk
    cargo-generate
    wasm-pack
    openssl
    openssl.dev
  ];

  home.sessionVariables = {
    OPENSSL_DIR = "${pkgs.openssl.dev}";
    OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
    OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
  };
}
