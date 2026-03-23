{...}: {
  networking = {
    networkmanager.enable = true;
    firewall.enable = true;
    firewall = {
      checkReversePath = "loose";
      trustedInterfaces = ["tailscale0"];
      allowedUDPPorts = [50000 6112 8080];
      allowedTCPPorts = [6112 8008 8080];
    };

    nameservers = ["1.1.1.1" "8.8.8.8"];
  };
}
