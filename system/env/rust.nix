{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    rustup
    trunk
    cargo-generate
    wasm-pack
    pkg-config
    openssl
    openssl.dev
  ];
}
