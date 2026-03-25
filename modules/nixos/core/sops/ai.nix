{ username, ... }:
{
  sops.secrets."openai/base" = {
    owner = username;
  };
  sops.secrets."openai/api_key" = {
    owner = username;
  };
}
