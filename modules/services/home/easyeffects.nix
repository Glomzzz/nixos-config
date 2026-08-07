{pkgs, ...}: {
  systemd.user.services.easyeffects = {
    Unit = {
      Description = "EasyEffects audio processor";
      After = [
        "pipewire.service"
        "wireplumber.service"
      ];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${pkgs.easyeffects}/bin/easyeffects --service-mode --hide-window";
      Restart = "on-failure";
    };
    Install.WantedBy = ["graphical-session.target"];
  };
}
