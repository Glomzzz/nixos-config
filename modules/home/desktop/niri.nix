{
  inputs,
  pkgs,
  ...
}: let
  niriOnly = ''${pkgs.systemd}/lib/systemd/systemd-xdg-autostart-condition "niri" ""'';
  xwaylandSatellite =
    inputs.xwayland-satellite.packages.${pkgs.stdenv.hostPlatform.system}.xwayland-satellite.overrideAttrs
    (old: {
      patches = (old.patches or []) ++ [../../../patches/xwayland-satellite-preserve-popup-parent.patch];
    });
in {
  services.clavis-shell = {
    enable = true;
    defaultWallpaper = ../../../assets/e022.jpg;
    language = "en_US";
    primaryOutput = "eDP-1";
    extraPackages = with pkgs; [
      brightnessctl
      kdePackages.dolphin
      kitty
      playerctl
      wireplumber
    ];
    xwaylandSatellite = {
      package = xwaylandSatellite;
      baseScale = 1.5;
    };
  };

  home.packages = [pkgs.kdePackages.polkit-kde-agent-1];

  systemd.user.services.polkit-kde-agent = {
    Unit = {
      Description = "KDE PolicyKit Authentication Agent";
      PartOf = ["graphical-session.target"];
      After = ["graphical-session.target"];
      Requisite = ["graphical-session.target"];
    };
    Service = {
      ExecCondition = niriOnly;
      ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
      Restart = "on-failure";
      Slice = "session-graphical.slice";
    };
    Install.WantedBy = ["niri.service"];
  };
}
