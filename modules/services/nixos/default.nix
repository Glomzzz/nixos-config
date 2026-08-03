{
  lib,
  pkgs,
  ...
}: {
  # httpProxy = "http://127.0.0.1:20172";
  # socksProxy = "socks5h://127.0.0.1:20170";
  # noProxy = "127.0.0.1,localhost,::1";

  imports = [
    ./docker.nix
    ./openssh.nix
    ./printing.nix
    ./tailscale.nix
    # ./sub2api.nix
  ];

  services = {
    speechd.enable = lib.mkForce false;

    v2raya = {
      enable = true;
      cliPackage = pkgs.xray;
    };
  };

  systemd.services.v2raya = {
    environment.V2RAYA_V2RAY_ASSETSDIR = "${pkgs.v2raya-assets}";
    path = [pkgs.kmod];
  };

  # networking.proxy = {
  #   default = httpProxy;
  #   allProxy = socksProxy;
  #   inherit noProxy;
  # };

  # environment.sessionVariables = {
  #   HTTP_PROXY = httpProxy;
  #   HTTPS_PROXY = httpProxy;
  #   ALL_PROXY = socksProxy;
  #   NO_PROXY = noProxy;
  # };
}
