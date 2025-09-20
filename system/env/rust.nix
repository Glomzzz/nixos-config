
{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    clang
    rustup
    trunk
    cargo-generate
    wasm-pack
  ];
}
