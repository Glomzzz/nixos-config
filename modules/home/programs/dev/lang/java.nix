{pkgs, ...}: {
  home.packages = with pkgs; [
    graalvmPackages.graalvm-oracle
    jdt-language-server # Java LSP
  ];
}
