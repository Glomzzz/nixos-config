{username, ...}: {
  sops.secrets."opencode/api_key" = {
    owner = username;
  };
  sops.secrets."opencode/password" = {
    owner = username;
  };
}
