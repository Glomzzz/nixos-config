{
  pkgs,
  home,
}: let
  archive =
    pkgs.lib.findSingle
    (p: pkgs.lib.getName p == "7zip-cli")
    (throw "7zip-cli missing from home.packages")
    (throw "multiple 7zip-cli packages in home.packages")
    home.home.packages;
in
  assert !(builtins.any (p: pkgs.lib.getName p == "p7zip") home.home.packages);
    pkgs.runCommand "7zip-cli-check"
    {nativeBuildInputs = [pkgs.diffutils];}
    ''
      mkdir input
      printf '7-Zip round-trip\n' > "input/file with spaces.txt"

      for command in 7zz 7z 7za 7zr; do
        test "$(readlink -f ${archive}/bin/$command)" = "${pkgs._7zz}/bin/7zz"
        for format in 7z zip; do
          archive_file="$PWD/$command.$format"
          (
            cd input
            ${archive}/bin/$command a -t"$format" "$archive_file" "file with spaces.txt" >/dev/null
          )
          ${archive}/bin/$command t "$archive_file" >/dev/null
          ${archive}/bin/$command x "$archive_file" -o"$command-$format" >/dev/null
          cmp "input/file with spaces.txt" "$command-$format/file with spaces.txt"
        done
      done

      echo '7zz and legacy command names passed 7z/ZIP round-trip tests'
      touch "$out"
    ''
