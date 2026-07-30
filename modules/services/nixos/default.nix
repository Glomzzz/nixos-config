{
  lib,
  pkgs,
  ...
}: let
  # httpProxy = "http://127.0.0.1:20172";
  # socksProxy = "socks5h://127.0.0.1:20170";
  # noProxy = "127.0.0.1,localhost,::1";

  v2rayAssets = pkgs.runCommand "v2raya-assets" {} ''
    mkdir -p "$out"
    ln -s ${pkgs.v2ray-geoip}/share/v2ray/geoip.dat "$out/geoip.dat"
    ln -s ${pkgs.v2ray-domain-list-community}/share/v2ray/geosite.dat "$out/geosite.dat"
  '';
in {
  imports = [
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
    environment.V2RAYA_V2RAY_ASSETSDIR = "${v2rayAssets}";
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
