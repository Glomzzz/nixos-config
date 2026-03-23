{...}: {
  networking = {
    networkmanager.enable = true;
    firewall.enable = true;
    firewall = {
      checkReversePath = "loose"; # 解决策略路由导致的警告[citation:1]
      trustedInterfaces = [ "tailscale0" ]; # 信任Tailscale虚拟接口
      allowedUDPPorts = [ 50000 6112 ]; # 允许Tailscale通信端口
      allowedTCPPorts = [6112 8008];
    };

    nameservers = [ "1.1.1.1" "8.8.8.8" ];
  };
}
