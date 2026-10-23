{pkgs, ...}: {
  services.v2raya = {
    enable = true;
    cliPackage = pkgs.xray;
  };

  systemd.services.v2raya = {
    # The web UI and API are local-only; proxy traffic still uses the normal
    # system networking stack.
    environment = {
      V2RAYA_ADDRESS = "127.0.0.1:2017";
      V2RAYA_V2RAY_ASSETSDIR = "${pkgs.v2raya-assets}";
    };
    path = [pkgs.kmod];
  };
}
