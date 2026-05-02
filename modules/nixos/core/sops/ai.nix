{
  username,
  config,
  ...
}:
{
  sops.secrets."apiapi/api_key" = {
    owner = username;
  };

  home-manager.users.${username}.home.sessionVariables.APIAPI_API_KEY_FILE =
    config.sops.secrets."apiapi/api_key".path;
}
