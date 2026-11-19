{
  inputs,
  lib,
  ...
}: let
  # Non-CN sources (cache.nixos.org, source tarballs, flake inputs) use the
  # mihomo mixed listener (mihomo/base.nix). Its rules still send CN destinations
  # direct. The USTC mirror and private ranges are excluded here, so they never
  # take the proxy hop.
  proxy = "http://127.0.0.1:20172";
  noProxy = lib.concatStringsSep "," [
    "localhost"
    "127.0.0.1"
    "::1"
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "100.64.0.0/10"
    "mirrors.ustc.edu.cn"
  ];
  proxyEnv = {
    http_proxy = proxy;
    https_proxy = proxy;
    no_proxy = noProxy;
    HTTP_PROXY = proxy;
    HTTPS_PROXY = proxy;
    NO_PROXY = noProxy;
  };
in {
  imports = [inputs.selector4nix.nixosModules.selector4nix];

  services.selector4nix = {
    enable = true;
    # The local listener is prepended, so cache.nixos.org stays as a fallback
    # whenever selector4nix is not running.
    configureSubstituter = "prepend";
    enablePersistentCaching = true;
    # Two upstream streams per host. Measured: four concurrent NAR downloads failed on
    # every route, while two succeeded on direct and both proxies.
    settings.network.max_concurrent_requests = 2;
    # The default 30 s is shorter than a 16 MB NAR takes through the proxies (28-62 s).
    settings.network.nar_timeout_secs = 300;
    settings.substituters = [
      # Lower priority value wins. USTC is preferred when it answers as fast.
      {
        url = "https://mirrors.ustc.edu.cn/nix-channels/store/";
        priority = 30;
      }
      {url = "https://cache.nixos.org/";}
    ];
  };

  # Upstream's own cache, from its README. It avoids compiling the Rust package
  # during deploy. Drop these two lines to build from source instead.
  nix.settings = {
    substituters = ["https://selector4nix.cachix.org/"];
    trusted-public-keys = ["selector4nix.cachix.org-1:wovVlT07In5JCVz2tFgxPQTLpnN8hZT6P/RwfFcz3KE="];
  };

  systemd.services = {
    # selector4nix fetches upstream narinfo and NARs with reqwest, which reads
    # these variables.
    selector4nix.environment = proxyEnv;
    # Fixed-output source fetches run in the daemon, so it needs the same proxy.
    nix-daemon.environment = proxyEnv;
  };
}
