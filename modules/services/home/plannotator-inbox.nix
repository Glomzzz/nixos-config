{
  lib,
  pkgs,
  ...
}: {
  systemd.user.services.plannotator-inbox = {
    Unit = {
      Description = "Plannotator Inbox";
    };
    Service = {
      # Foreground run without a browser tab. A plain `plannotator inbox` run
      # would also connect agents by editing their config files, which Home
      # Manager owns, so that step stays off.
      ExecStart = lib.escapeShellArgs [
        (lib.getExe pkgs.plannotator)
        "inbox"
        "--no-open"
      ];
      Environment = ["PLANNOTATOR_INBOX_CONNECT=0"];
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = ["default.target"];
  };
}
