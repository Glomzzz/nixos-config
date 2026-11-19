{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  # Match the declared root instead of probing a different mounted device.
  uuid = lib.removePrefix "/dev/disk/by-uuid/" config.fileSystems."/".device;
  uid = toString config.users.users.${username}.uid;
in {
  assertions = [
    {
      assertion = config.fileSystems."/".fsType == "btrfs" && lib.hasPrefix "/dev/disk/by-uuid/" config.fileSystems."/".device;
      message = "The storage-health monitor requires a UUID-backed Btrfs root.";
    }
  ];

  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = ["/"];
    interval = "monthly";
    limit = "100M";
  };

  systemd = {
    services = {
      "btrfs-scrub@".onFailure = ["maintenance-alert@%n.service"];
      btrfs-allocation-monitor = {
        description = "Read-only Btrfs root allocation pressure monitor";
        after = ["local-fs.target"];
        onFailure = ["maintenance-alert@%n.service"];
        environment.DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/${uid}/bus";
        serviceConfig = {
          Type = "oneshot";
          User = username;
          StateDirectory = "btrfs-allocation-monitor";
          StateDirectoryMode = "0700";
          ExecStart = "${pkgs.python3}/bin/python3 ${../../scripts/btrfs-allocation-monitor.py} --uuid ${uuid} --state /var/lib/btrfs-allocation-monitor/notification.json --notify-program ${pkgs.libnotify}/bin/notify-send";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
        };
      };
    };
    timers.btrfs-allocation-monitor = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "10min";
        OnUnitActiveSec = "1h";
        RandomizedDelaySec = "5min";
      };
    };
  };
}
