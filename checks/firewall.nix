{
  pkgs,
  config,
}: let
  firewall = config.networking.firewall;
  rules = firewall.extraInputRules;
  settings = pkgs.writeText "firewall-settings.json" (builtins.toJSON {
    inherit (firewall) allowedTCPPorts allowedTCPPortRanges allowedUDPPorts allowedUDPPortRanges backend;
    inherit rules;
    table = config.networking.nftables.tables.nixos-fw.content;
  });
in
  assert config.networking.nftables.enable;
    pkgs.runCommand "profile-scoped-firewall-check"
    {
      nativeBuildInputs = [pkgs.python3];
      # Realize the module's nft --check validated ruleset, not a live reload.
      ruleset = builtins.elemAt config.systemd.services.nftables.serviceConfig.ExecStart 1;
    }
    ''
      export PYTHONDONTWRITEBYTECODE=1
      python3 - ${settings} ${../scripts/sync-home-firewall.py} <<'PY'
      import json
      import runpy
      import sys
      settings = json.load(open(sys.argv[1]))
      assert settings["backend"] == "nftables"
      for key in ("allowedTCPPorts", "allowedTCPPortRanges", "allowedUDPPorts", "allowedUDPPortRanges"):
          assert settings[key] == []
      rules = settings["rules"].splitlines()
      assert len(rules) == 9
      assert all(rule.startswith(('iifname "tailscale0" ', 'iifname @home-lan-interfaces ')) for rule in rules)
      assert sum("ip saddr 192.168.50.0/24" in rule for rule in rules) == 3
      assert "set home-lan-interfaces" in settings["table"]
      assert "type ifname" in settings["table"]
      assert "10.0.0.0/8" not in settings["rules"]
      sync = runpy.run_path(sys.argv[2])
      profiles = {"home-wifi", "home-wired"}
      active = "home-wifi:wlan0\nhome-wired:eth0\nother:guest0\n"
      assert sync["approved_interfaces"](active, profiles) == ["eth0", "wlan0"]
      assert sync["approved_interfaces"](active, profiles, "wlan0") == ["eth0"]
      assert sync["approved_interfaces"]("", profiles) == []
      assert sync["transaction"]([]) == "flush set inet nixos-fw home-lan-interfaces\n"
      transaction = sync["transaction"](["eth0"])
      assert transaction.endswith('add element inet nixos-fw home-lan-interfaces { "eth0" }\n')
      print("Profile selection, disconnect removal, fail-closed reconciliation, and generated nftables passed")
      PY
      touch "$out"
    ''
