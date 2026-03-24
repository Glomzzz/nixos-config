{...}: {
  networking = {
    networkmanager.enable = true;
    firewall.enable = true;
    firewall = {
      checkReversePath = "loose";
      trustedInterfaces = ["tailscale0"]; # Tailscale trust
      allowedUDPPorts = [
        50000
        6112
      ]; # Tailscale trust
      allowedTCPPorts = [
        6112
        8008
      ];
    };

    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ];
  };
}
