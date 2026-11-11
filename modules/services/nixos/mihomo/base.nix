# mihomo base configuration. render.py adds the proxies, the proxy groups and the API
# secret at start. The rules and DNS policy below refer to the groups render.py
# defines (proxy, auto, dns-auto, ai) and to the VLESS nodes (vless-hk, vless-sg).
{dashboard}: let
  # Local explicit-proxy listener (sing-box mixed-in). Only the listener-specific
  # rules below match on it; TUN traffic takes the general path.
  mixedPort = 20172;

  # Bilibili cn-hk CDN nodes. GeoIP lists them as mainland, but direct connections
  # time out from this network, so they use the proxy. Extend when other nodes fail
  # the same way.
  proxyCidrs = ["103.151.151.0/24" "124.238.244.202/32"];

  # MetaCubeX geo lists. Each file lives under the home directory so the NixOS module
  # can seed it for an offline start. Downloads go through the auto group.
  ruleSet = name: behavior: file: {
    type = "http";
    inherit behavior;
    url = "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/meta/geo/${file}.list";
    path = "./ruleset/${name}.list";
    format = "text";
    interval = 86400;
    proxy = "auto";
  };

  # OpenAI, Anthropic and Gemini exit through vless-sg (the Singapore server). Their
  # names resolve through vless-sg as well, so no domestic resolver answers for them.
  # When vless-sg is down, these connections fail.
  aiSets = ["geosite-openai" "geosite-anthropic" "geosite-google-gemini"];
  aiNameserver = ["https://1.1.1.1/dns-query#vless-sg"];

  privateCidrs = [
    "0.0.0.0/8"
    "10.0.0.0/8"
    "127.0.0.0/8"
    "169.254.0.0/16"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "224.0.0.0/4"
    "255.255.255.255/32"
  ];
  privateCidrs6 = ["::1/128" "fc00::/7" "fe80::/10" "ff00::/8"];

  # Traffic from the local listener goes to the proxy even when a mainland rule would match.
  localRules = set: ["AND,((IN-PORT,${toString mixedPort}),(RULE-SET,${set})),proxy"];
in {
  mixed-port = mixedPort;
  socks-port = 20170;
  port = 20171;
  bind-address = "127.0.0.1";
  allow-lan = false;
  ipv6 = false;
  # Rule mode only: mihomo's global and direct modes skip every rule below.
  mode = "rule";
  # Temporary: info names the outbound in connection errors. Revert to "warn" after diagnosis.
  log-level = "info";
  external-controller = "127.0.0.1:9090";
  # The dashboard is served from the controller at /ui. Browser pages may call the API
  # only from the controller's own origins.
  external-ui = "${dashboard}";
  external-controller-cors = {
    allow-origins = ["http://127.0.0.1:9090" "http://localhost:9090"];
    allow-private-network = false;
  };
  profile = {
    store-selected = true;
    store-fake-ip = true;
  };

  tun = {
    enable = true;
    stack = "mixed";
    device = "mihomo0";
    # A fixed address: the system resolver points at 172.19.0.2 while the TUN is up.
    inet4-address = ["172.19.0.1/30"];
    mtu = 1500;
    auto-route = true;
    # Off: with auto-redirect, mihomo 1.19.33 fails at start ("netlink receive: file exists")
    # when it builds its nftables address sets, and the TUN never comes up. auto-route alone
    # still captures all traffic.
    auto-redirect = false;
    auto-detect-interface = true;
    dns-hijack = ["any:53"];
    strict-route = false;
    # Local, tailnet and IPv6-only ranges stay off the TUN, as in sing-box.
    route-exclude-address =
      ["127.0.0.0/8" "10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16" "169.254.0.0/16" "100.64.0.0/10" "224.0.0.0/4"]
      ++ ["::1/128" "fc00::/7" "fe80::/10" "ff00::/8"];
    exclude-interface = ["tailscale0"];
  };

  sniffer = {
    enable = true;
    parse-pure-ip = true;
    # Recover the domain for rule matching; the connection keeps its destination address.
    override-destination = false;
    sniff = {
      TLS.ports = [443 8443];
      HTTP.ports = [80 "8080-8880"];
      QUIC.ports = [443];
    };
  };

  dns = {
    enable = true;
    ipv6 = false;
    # Fake addresses keep the domain attached to each connection (sing-box reverse_mapping),
    # so AI names still route to vless-sg when an application connects by address.
    enhanced-mode = "fake-ip";
    fake-ip-range = "198.18.0.1/16";
    fake-ip-filter-mode = "rule";
    # Mainland and local names get real addresses, so geoip-cn and proxyCidrs match them.
    fake-ip-filter = [
      "RULE-SET,geosite-cn,real-ip"
      "DOMAIN-SUFFIX,local,real-ip"
      "DOMAIN-SUFFIX,lan,real-ip"
      "DOMAIN-SUFFIX,home.arpa,real-ip"
      "DOMAIN-SUFFIX,ts.net,real-ip"
      "DOMAIN-REGEX,^[^.]+$,real-ip"
      "MATCH,fake-ip"
    ];
    # Everything else resolves through dns-auto: the proxy pool, with vless-hk as fallback.
    nameserver = ["https://1.1.1.1/dns-query#dns-auto"];
    # Node domains and direct connections use the system resolver, as sing-box local-dns did.
    proxy-server-nameserver = ["system"];
    direct-nameserver = ["system"];
    nameserver-policy =
      builtins.listToAttrs (map (set: {
          name = "rule-set:${set}";
          value = aiNameserver;
        })
        aiSets)
      // {
        "rule-set:geosite-cn" = ["system"];
        "+.local" = ["system"];
        "+.lan" = ["system"];
        "+.home.arpa" = ["system"];
        "+.ts.net" = ["system"];
      };
  };

  rule-providers = {
    geosite-openai = ruleSet "geosite-openai" "domain" "geosite/openai";
    geosite-anthropic = ruleSet "geosite-anthropic" "domain" "geosite/anthropic";
    geosite-google-gemini = ruleSet "geosite-google-gemini" "domain" "geosite/google-gemini";
    geosite-geolocation-not-cn = ruleSet "geosite-geolocation-not-cn" "domain" "geosite/geolocation-!cn";
    geosite-cn = ruleSet "geosite-cn" "domain" "geosite/cn";
    geoip-hk = ruleSet "geoip-hk" "ipcidr" "geoip/hk";
    geoip-mo = ruleSet "geoip-mo" "ipcidr" "geoip/mo";
    geoip-cn = ruleSet "geoip-cn" "ipcidr" "geoip/cn";
  };

  # First match wins. The order follows sing-box route rules, so the same traffic is
  # selected in the same order.
  rules =
    [
      "PROCESS-NAME,nix-daemon,DIRECT"
      # Dota 2 goes through vless-hk. Its IPv6 path is rejected so the game falls back to IPv4.
      "AND,((PROCESS-NAME,dota2),(IP-CIDR6,::/0)),REJECT"
      "PROCESS-NAME,dota2,vless-hk"
      "IP-CIDR,100.64.0.0/10,DIRECT,no-resolve"
      "IP-CIDR6,fd7a:115c:a1e0::/48,DIRECT,no-resolve"
    ]
    ++ map (set: "RULE-SET,${set},ai") aiSets
    ++ map (cidr: "IP-CIDR,${cidr},DIRECT,no-resolve") privateCidrs
    ++ map (cidr: "IP-CIDR6,${cidr},DIRECT,no-resolve") privateCidrs6
    ++ [
      "DOMAIN-SUFFIX,local,DIRECT"
      "DOMAIN-SUFFIX,lan,DIRECT"
      "DOMAIN-SUFFIX,home.arpa,DIRECT"
      "DOMAIN-SUFFIX,ts.net,DIRECT"
      "DOMAIN-REGEX,^[^.]+$,DIRECT"
    ]
    ++ localRules "geosite-geolocation-not-cn"
    ++ map (cidr: "IP-CIDR,${cidr},proxy,no-resolve") proxyCidrs
    ++ [
      "RULE-SET,geosite-cn,DIRECT"
    ]
    ++ localRules "geoip-hk"
    ++ localRules "geoip-mo"
    ++ [
      "RULE-SET,geoip-cn,DIRECT"
      "MATCH,proxy"
    ];
}
