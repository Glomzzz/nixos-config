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

  home-manager.users.${username}.programs.nushell.extraEnv = ''
    if ("${githubPatFile}" | path exists) {
      $env.GITHUB_PAT_TOKEN = (open --raw "${githubPatFile}" | str trim)
    }
  '';
}
