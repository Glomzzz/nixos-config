{pkgs, ...}: {
  home.packages = with pkgs; [
    rustup
    trunk
    cargo-generate
    wasm-pack
    pkg-config
    openssl
    openssl.dev
  ];
}
