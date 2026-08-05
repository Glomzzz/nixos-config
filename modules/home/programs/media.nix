{pkgs, ...}: {
  programs.obs-studio.enable = true;

  home.packages = with pkgs; [
    alsa-utils
    easyeffects
    ffmpeg
    gimp3
    pavucontrol
    qpwgraph
    vlc
  ];

  systemd.user.services.easyeffects = {
    Unit = {
      Description = "EasyEffects audio processor";
      After = [
        "graphical-session.target"
        "pipewire.service"
        "wireplumber.service"
      ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
      PartOf = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${pkgs.easyeffects}/bin/easyeffects --service-mode";
      Restart = "on-failure";
      RestartSec = 3;
    };
    Install.WantedBy = ["graphical-session.target"];
  };
}
