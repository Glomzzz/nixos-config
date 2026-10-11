{
  config,
  lib,
  pkgs,
  ...
}: let
  prepareSnapshots = pkgs.writeShellApplication {
    name = "prepare-root-snapshots";
    runtimeInputs = [pkgs.btrfs-progs pkgs.coreutils];
    text = ''
      # A nested subvolume is not recursively included in root snapshots.
      # Never replace an existing directory or follow a symlink here.
      if [ -L /.snapshots ]; then
        echo "Refusing to use a symlink as /.snapshots" >&2
        exit 1
      fi
      if [ -e /.snapshots ]; then
        btrfs subvolume show /.snapshots >/dev/null
      else
        btrfs subvolume create /.snapshots
      fi
      chmod 700 /.snapshots
    '';
  };
in {
  assertions = [
    {
      assertion = config.fileSystems."/".fsType == "btrfs";
      message = "Zephyrus root snapshots require a Btrfs root filesystem.";
    }
  ];

  services.snapper = {
    # Disable automatic whole-root snapshots after the metadata-full incident.
    # Keep the configuration for manual recovery and cleanup of existing snapshots.
    snapshotRootOnBoot = false;
    configs.root = {
      SUBVOLUME = "/";
      FSTYPE = "btrfs";
      TIMELINE_CREATE = false;
      TIMELINE_CLEANUP = true;
      TIMELINE_LIMIT_HOURLY = 6;
      TIMELINE_LIMIT_DAILY = 7;
      TIMELINE_LIMIT_WEEKLY = 4;
      TIMELINE_LIMIT_MONTHLY = 2;
      TIMELINE_LIMIT_YEARLY = 0;
      NUMBER_CLEANUP = true;
      NUMBER_LIMIT = 5;
      NUMBER_LIMIT_IMPORTANT = 2;
      EMPTY_PRE_POST_CLEANUP = true;
    };
  };

  # NixOS installs the timeline timer whenever any Snapper config exists,
  # even with TIMELINE_CREATE disabled. Mask the creation units as well.
  systemd.timers.snapper-timeline.enable = false;

  systemd.services = {
    prepare-root-snapshots = {
      description = "Prepare the private Snapper root snapshot subvolume";
      requires = ["local-fs.target"];
      after = ["local-fs.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe prepareSnapshots;
      };
    };
    snapper-boot.enable = false;
    snapper-timeline.enable = false;
    snapper-cleanup = {
      requires = ["prepare-root-snapshots.service"];
      after = ["prepare-root-snapshots.service"];
    };
    snapperd = {
      requires = ["prepare-root-snapshots.service"];
      after = ["prepare-root-snapshots.service"];
    };
  };
}
