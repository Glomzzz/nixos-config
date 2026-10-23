_: {
  networking = {
    networkmanager.enable = true;
    firewall.enable = true;
    firewall = {
      checkReversePath = "loose";
    };

    # Let NetworkManager and systemd-resolved preserve DHCP, VPN, and split-DNS
    # data instead of replacing it with fixed public resolvers.
    nameservers = [];
  };

  services.resolved.enable = true;
}
