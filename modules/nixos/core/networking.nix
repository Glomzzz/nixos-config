{pkgs, ...}: {
  programs.nm-applet = {
    enable = true;
    indicator = true;
  };

  systemd.user.services.nm-applet.serviceConfig = {
    ExecCondition = ''${pkgs.systemd}/lib/systemd/systemd-xdg-autostart-condition "Hyprland" ""'';
    Restart = "on-failure";
    RestartSec = 3;
  };

  networking = {
    networkmanager.enable = true;
    firewall.enable = true;
    firewall = {
      checkReversePath = "loose";
    };

    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ];
  };
}
