{
  username,
  config,
  ...
}:
{
  sops.secrets."skillw/api_key" = {
    owner = username;
  };

  home-manager.users.${username}.home.sessionVariables.SKILLW_API_KEY_FILE =
    config.sops.secrets."skillw/api_key".path;
}
