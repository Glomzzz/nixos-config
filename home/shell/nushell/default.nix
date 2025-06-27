{pkgs,...}:
{
  home.packages = with pkgs; [
    nu_scripts
  ];
  programs.nushell = {
    enable = true;
    package = pkgs.stable.nushell;
    configFile.text = with builtins;
      let
        lib = pkgs.lib;
        completions = pkgs.nu_scripts.outPath + "/share/nu_scripts/custom-completions";
        
        flatten = lib.lists.flatten;

        isDir = path: pathExists path && readFileType path == "directory";
        isNuFile = path: match ".*\\.nu$" path != null;
        
        collectNuFiles = dir: 
          let
            getSubPaths = path: 
              map (name: "${dir}/${name}")
                  (filter (name: name != "auto-generate") (attrNames (readDir path)));
            helper = paths: 
              map (path: 
                    if      isNuFile path  then  path 
                    else if isDir    path  then  collectNuFiles path
                    else                         []
                  ) 
                  paths;
          in
            helper (getSubPaths dir);
        
        getNuFiles = flatten (collectNuFiles completions);

        processCompletions = concatStringsSep "\n" (
          map (path: "use ${path} *") getNuFiles
        );

      in
      ''
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
    
    envFile.source = ./env.nu;
  };
}
