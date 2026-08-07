{pkgs, ...}: {
  home.packages = [
    pkgs.nu_scripts
  ];

  programs.nushell = {
    enable = true;
    package = pkgs.nushell;
    configFile.text = with builtins; let
      inherit (pkgs) lib;
      completions = pkgs.nu_scripts.outPath + "/share/nu_scripts/custom-completions";

      flatten = lib.lists.flatten;

      isDir = path: pathExists path && readFileType path == "directory";
      isNuFile = path: match ".*\\.nu$" path != null;

      collectNuFiles = dir: let
        getSubPaths = path:
          map (name: "${dir}/${name}") (filter (name: name != "auto-generate") (attrNames (readDir path)));
        helper = paths:
          map (
            path:
              if isNuFile path
              then path
              else if isDir path
              then collectNuFiles path
              else []
          )
          paths;
      in
        helper (getSubPaths dir);

      getNuFiles = flatten (collectNuFiles completions);

      processCompletions = concatStringsSep "\n" (map (path: "use ${path} *") getNuFiles);
    in ''
      $env.SHELL = "${pkgs.nushell}/bin/nu";
      $env.config.show_banner = false

      $env.config = {
        show_banner: false,
        completions: {
          case_sensitive: false
          quick: true
          partial: true
        }
      }

      ${processCompletions}

      def --wrapped ssh [...args] {
        with-env { SHELL: "${pkgs.runtimeShell}" } {
          ^ssh ...$args
        }
      }
    '';
  };
}
