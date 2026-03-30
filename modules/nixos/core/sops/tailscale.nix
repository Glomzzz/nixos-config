{ username, ... }:
{
  sops.secrets."tailscale/ip" = {
    owner = username;
  };
}
