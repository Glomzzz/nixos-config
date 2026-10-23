{lib, ...}: let
  privateIPv4 = "{ 10.0.0.0/8, 100.64.0.0/10, 172.16.0.0/12, 192.168.0.0/16 }";
  privateIPv6 = "{ fc00::/7, fe80::/10 }";
  serviceTCPPorts = "{ 9757, 27036, 27037 }";
  serviceUDPPorts = "{ 5353, 9757, 10400, 10401, 27036 }";
in {
  networking = {
    networkmanager.enable = true;
    nftables.enable = true;
    firewall = {
      enable = true;
      backend = "nftables";
      checkReversePath = "loose";

      # Service modules normally add their ports on every interface. Replace
      # those broad rules with source-scoped LAN, Tailscale, and ULA rules.
      allowedTCPPorts = lib.mkForce [];
      allowedUDPPorts = lib.mkForce [];
      allowedUDPPortRanges = lib.mkForce [];
      extraInputRules = ''
        ip saddr ${privateIPv4} tcp dport ${serviceTCPPorts} accept
        ip saddr ${privateIPv4} udp dport ${serviceUDPPorts} accept
        ip saddr ${privateIPv4} udp dport 27031-27035 accept
        ip6 saddr ${privateIPv6} tcp dport ${serviceTCPPorts} accept
        ip6 saddr ${privateIPv6} udp dport ${serviceUDPPorts} accept
        ip6 saddr ${privateIPv6} udp dport 27031-27035 accept
      '';
    };

    # Let NetworkManager and systemd-resolved preserve DHCP, VPN, and split-DNS
    # data instead of replacing it with fixed public resolvers.
    nameservers = [];
  };

  services.resolved.enable = true;
}
