{pkgs}:
pkgs.symlinkJoin {
  name = "7zip-cli-${pkgs._7zz.version}";
  paths = [pkgs._7zz];

  # Keep existing CLI callers and archive-manager integrations working. These
  # names all use the maintained full 7-Zip implementation, not p7zip's subsets.
  postBuild = ''
    for command in 7z 7za 7zr; do
      ln -s 7zz "$out/bin/$command"
    done
  '';

  inherit (pkgs._7zz) meta;
}
