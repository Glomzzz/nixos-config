{pkgs, ...}: let
  nu_scripts = pkgs.callPackage (
    {
      lib,
      stdenvNoCC,
      fetchFromGitHub,
      unstableGitUpdater,
    }:
      stdenvNoCC.mkDerivation {
        pname = "nu_scripts";
        version = "0-unstable-2025-09-24";

        src = fetchFromGitHub {
          owner = "nushell";
          repo = "nu_scripts";
          rev = "7ea6780a4137bef1d683fb16989c19a945891b54";
          hash = "sha256-Bof9bsQZnjtc9MLcuTIjdtsX/lbWGKc1u9HgGZp8uD8=";
        };

        installPhase = ''
          runHook preInstall

          mkdir -p $out/share/nu_scripts
          mv ./* $out/share/nu_scripts

          runHook postInstall
        '';

        passthru.updateScript = unstableGitUpdater {};

        meta = {
          description = "Place to share Nushell scripts with each other";
          homepage = "https://github.com/nushell/nu_scripts";
          license = lib.licenses.mit;
          platforms = lib.platforms.unix;
          maintainers = [lib.maintainers.CardboardTurkey];
        };
      }
  ) {};
in {
  home.packages = [
    nu_scripts
  ];

  programs.nushell = {
    enable = true;
    package = pkgs.nushell;
    configFile.text = with builtins; let
      lib = pkgs.lib;
      completions = nu_scripts.outPath + "/share/nu_scripts/custom-completions";

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
      $env.SHELL = "nu";
      $env.config.show_banner = false

      let carapace_completer = {|spans|
      carapace $spans.0 nushell $spans | from json
      }
      $env.config = {
        show_banner: false,
        completions: {
          case_sensitive: false
          quick: true
          partial: true
        }
      }
      ${processCompletions}
    '';

    envFile.text = ''
      mkdir ~/.cache/starship
      starship init nu | sed "s/size -c/size/" | save ~/.cache/starship/init.nu -f
    '';
  };
}
