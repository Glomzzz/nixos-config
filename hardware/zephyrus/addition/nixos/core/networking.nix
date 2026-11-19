# Tailnet and approved home-LAN access to WiVRn, mDNS, and Steam Remote Play.
# @home-lan-interfaces is maintained by home-firewall-sync in
# modules/nixos/core/networking.nix.
_: let
  serviceTCPPorts = "{ 9757, 27036, 27037 }";
  serviceUDPPorts = "{ 5353, 9757, 10400, 10401, 27036 }";
in {
  networking.firewall.extraInputRules = ''
    iifname "tailscale0" tcp dport ${serviceTCPPorts} accept
    iifname "tailscale0" udp dport ${serviceUDPPorts} accept
    iifname "tailscale0" udp dport 27031-27035 accept
    iifname @home-lan-interfaces ip saddr 192.168.50.0/24 tcp dport ${serviceTCPPorts} accept
    iifname @home-lan-interfaces ip saddr 192.168.50.0/24 udp dport ${serviceUDPPorts} accept
    iifname @home-lan-interfaces ip saddr 192.168.50.0/24 udp dport 27031-27035 accept
    iifname @home-lan-interfaces ip6 saddr fe80::/10 tcp dport ${serviceTCPPorts} accept
    iifname @home-lan-interfaces ip6 saddr fe80::/10 udp dport ${serviceUDPPorts} accept
    iifname @home-lan-interfaces ip6 saddr fe80::/10 udp dport 27031-27035 accept
  '';
}
