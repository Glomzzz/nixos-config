{config, ...}: {
  services.tailscale = {
    enable = true;
    # serve.enable = true;
  };
  networking.firewall = {
    trustedInterfaces = ["tailscale0"];
    allowedUDPPorts = [
      config.services.tailscale.port
      6112
      9944
      8082
      9942
    ];
    allowedTCPPorts = [6112 9944 8082 9942];
  };
}
