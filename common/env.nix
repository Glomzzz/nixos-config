{pkgs,...} : {
    environment.systemPackages = with pkgs; [
      clang
      cargo
      rustc
  ];
}