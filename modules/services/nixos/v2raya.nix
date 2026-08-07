{pkgs, ...}: {
  services.v2raya = {
    enable = true;
    cliPackage = pkgs.xray;
  };

  systemd.services.v2raya = {
    environment.V2RAYA_V2RAY_ASSETSDIR = "${pkgs.v2raya-assets}";
    path = [pkgs.kmod];
  };
}
