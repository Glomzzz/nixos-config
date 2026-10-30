{
  pkgs,
  config,
}:
assert config.services.btrfs.autoScrub.enable;
assert config.services.btrfs.autoScrub.fileSystems == ["/"];
assert config.services.btrfs.autoScrub.interval == "monthly";
assert !config.services.snapper.configs.root.TIMELINE_CREATE;
assert !config.services.snapper.snapshotRootOnBoot;
assert config.systemd.services.btrfs-allocation-monitor.serviceConfig.User == "glom";
assert config.systemd.services.btrfs-allocation-monitor.serviceConfig.ProtectSystem == "strict";
  pkgs.runCommand "storage-health-check"
  {nativeBuildInputs = [pkgs.python3];}
  ''
    export PYTHONDONTWRITEBYTECODE=1
    python3 ${../scripts/tests/btrfs-allocation.py} ${../scripts/btrfs-allocation-monitor.py}
    touch "$out"
  ''
