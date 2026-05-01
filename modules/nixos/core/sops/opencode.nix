{username, ...}: {
  sops.secrets."opencode/password" = {
    owner = username;
  };
}
