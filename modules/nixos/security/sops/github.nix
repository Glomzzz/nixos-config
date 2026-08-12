{
  config,
  username,
  ...
}: let
  githubPatFile = config.sops.secrets."github/pat".path;
in {
  sops.secrets."github/pat" = {
    owner = username;
  };

  home-manager.users.${username}.programs.fish.shellInit = ''
    if test -r "${githubPatFile}"
      set --global --export GITHUB_PAT_TOKEN (string trim < "${githubPatFile}")
    end
  '';
}
