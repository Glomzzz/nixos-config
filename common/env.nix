{pkgs,...} : {
    environment.systemPackages = with pkgs; [
      clang
      # rustup to manage rust
      # there will be errors if u install cargo & rustc with rustup here,
      # due to some IDE will not recognize the rustc & cargo installed by rustup.
      rustup
      # java
      openjdk
  ];
}