{
  config,
  pkgs,
}: let
  home = config.home-manager.users.glom;
  service = home.systemd.user.services.yubikey-touch-detector;
  detector =
    pkgs.lib.findFirst (package: pkgs.lib.getName package == "yubikey-touch-detector")
    (throw "YubiKey touch detector missing from home.packages")
    home.home.packages;
  command = pkgs.lib.concatStringsSep " " service.Service.ExecStart;
in
  assert builtins.elem "graphical-session.target" service.Install.WantedBy;
  assert builtins.elem "graphical-session.target" service.Unit.PartOf;
  assert builtins.elem "gpg-agent.socket" service.Unit.Wants;
  assert builtins.elem "gpg-agent-ssh.socket" service.Unit.Wants;
  assert pkgs.lib.hasPrefix "${detector}/bin/yubikey-touch-detector " command;
  assert pkgs.lib.hasInfix "{{.Requesters}} requires a yubikey touch" command;
  assert pkgs.lib.hasInfix "--notify --no-socket" command;
  assert builtins.elem "GNUPGHOME=${home.programs.gpg.homedir}" service.Service.Environment;
  assert builtins.elem "YUBIKEY_TOUCH_DETECTOR_PAM_DIR=/run/yubikey-touch/${home.home.username}" service.Service.Environment;
  assert service.Service.Restart == "on-failure";
  assert service.Service.TimeoutStopSec >= 10;
    pkgs.runCommand "yubikey-touch-check" {} ''
      # Building the detector runs upstream and requester tests with Go's race
      # detector. --help validates packaging without touching real agent sockets.
      ${detector}/bin/yubikey-touch-detector --help 2> help.txt
      grep -q notify-title help.txt
      touch "$out"
    ''
