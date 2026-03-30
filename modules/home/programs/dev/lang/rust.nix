{ pkgs, ... }:
{
  home.packages = with pkgs; [
    rustup
    trunk
    cargo-generate
    wasm-pack
    openssl
    openssl.dev
  ];
}
