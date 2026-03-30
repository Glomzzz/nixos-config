{ config, ... }:
{
  services.tailscale = {
    enable = true;
    # serve.enable = true;
  };
  networking.firewall = {
    checkReversePath = "loose";
    trustedInterfaces = [ "tailscale0" ];
    allowedUDPPorts = [
      config.services.tailscale.port
      6112
    ];
    allowedTCPPorts = [ 6112 ];
  };
}
