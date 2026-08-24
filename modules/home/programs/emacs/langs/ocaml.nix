{pkgs, ...}: {
  home.packages = with pkgs.ocaml-ng.ocamlPackages_latest; [
    ocaml
    dune_3
    ocaml-lsp
    ocamlformat
    utop
  ];
}
