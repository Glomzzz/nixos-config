{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  detector = import ../../../../pkgs/yubikey-touch-detector {inherit pkgs;};
in {
  home.packages = [detector];

  systemd.user.services.yubikey-touch-detector = {
    Unit = {
      Description = "Identify YubiKey touch requests";
      After = ["graphical-session.target" "gpg-agent.socket" "gpg-agent-ssh.socket"];
      Wants = ["gpg-agent.socket" "gpg-agent-ssh.socket"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      ExecStart = lib.escapeShellArgs [
        (lib.getExe detector)
        "--notify"
        "--no-socket"
        "--notify-title"
        "{{.Requesters}} requires a yubikey touch"
        "--notify-body"
        "Touch only if you initiated this operation."
      ];
      Environment = [
        "GNUPGHOME=${config.programs.gpg.homedir}"
        "YUBIKEY_TOUCH_DETECTOR_PAM_DIR=/run/yubikey-touch/${username}"
        "PATH=${lib.makeBinPath [config.programs.gpg.package]}"
      ];
      Restart = "on-failure";
      RestartSec = 2;
      # Graceful termination lets the detector restore the GPG/SSH sockets.
      TimeoutStopSec = 15;
    };
    Install.WantedBy = ["graphical-session.target"];
  };
}
