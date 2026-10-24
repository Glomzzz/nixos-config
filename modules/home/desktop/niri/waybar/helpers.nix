{pkgs}: {
  # GtkBuilder IDs are matched against settings.nix's menu-actions. Nesting
  # uses real submenus; stateful check marks are deliberately not used because
  # Waybar constructs this menu only once and cannot synchronize their state.
  powerMenu = ./power-menu.xml;

  # asusd owns this host's Quiet/Balanced/Performance profiles, not TLP or PPD.
  setProfile = pkgs.writeShellApplication {
    name = "waybar-set-profile";
    runtimeInputs = [pkgs.asusctl pkgs.coreutils pkgs.libnotify];
    text = builtins.readFile ./scripts/set-profile.sh;
  };

  # A transient user unit owns the idle inhibitor across bar restarts. It does
  # not inhibit sleep, so the lid still suspends and before-sleep still locks.
  idleInhibit = pkgs.writeShellApplication {
    name = "waybar-idle-inhibit";
    runtimeInputs = [pkgs.coreutils pkgs.systemd pkgs.libnotify];
    text = builtins.readFile ./scripts/idle-inhibit.sh;
  };

  weatherScript = pkgs.writeShellApplication {
    name = "waybar-weather";
    runtimeInputs = [pkgs.curl pkgs.jq];
    text = builtins.readFile ./scripts/weather.sh;
  };

  netspeed = pkgs.writeShellApplication {
    name = "waybar-netspeed";
    runtimeInputs = [pkgs.coreutils pkgs.gawk pkgs.jq pkgs.networkmanager];
    text = builtins.readFile ./scripts/netspeed.sh;
  };
}
