{
  pkgs,
  config,
}: let
  backup = config.services.restic.backups.mac-mini;
  service = config.systemd.services.restic-backups-mac-mini;
  excludes = pkgs.writeText "tested-backup-exclusions" (builtins.concatStringsSep "\n" (
    map (path: pkgs.lib.removePrefix "/home/glom/" path) backup.exclude
  ));
in
  assert backup.repository == "sftp:glom@mac-mini:/Users/glom/Backups/nixos-restic";
  assert backup.paths == ["/home/glom"];
  assert (backup.timerConfig != null) == config.services.mac-mini-backup.enable;
  assert !backup.initialize && !backup.createWrapper;
  assert backup.passwordFile == "%d/password";
  assert service.serviceConfig.LoadCredential
  == [
    "password:/var/lib/nixos-backup/password"
    "ssh-key:/var/lib/nixos-backup/ssh-key"
    "known-hosts:/var/lib/nixos-backup/known-hosts"
  ];
    pkgs.runCommand "mac-mini-backup-check"
    {
      nativeBuildInputs = [pkgs.restic pkgs.python3];
      helpers = builtins.filter (package: pkgs.lib.getName package == "nixos-backup") config.environment.systemPackages;
      # Realize the shellchecked sftp adapter and systemd backup command graph.
      options = backup.extraOptions;
    }
    ''
      export HOME="$TMPDIR/home" RESTIC_REPOSITORY="$TMPDIR/repository" RESTIC_PASSWORD_FILE="$TMPDIR/password"
      mkdir -p "$HOME"
      printf 'isolated-test-password\n' > "$RESTIC_PASSWORD_FILE"
      restic init
      mkdir -p source/{Documents,.cache,.local/share/Steam/steamapps,mnt}
      printf 'restore me\n' > source/Documents/important.txt
      printf 'not backed up\n' | tee source/.cache/temp source/.local/share/Steam/steamapps/game source/mnt/remote >/dev/null
      cd source
      restic backup . --tag home --exclude-file=${excludes}
      restic forget --prune --keep-daily 7 --keep-weekly 4 --keep-monthly 12
      restic check --read-data
      restic restore latest --target "$TMPDIR/restore"
      cmp Documents/important.txt "$TMPDIR/restore/Documents/important.txt"
      test ! -e "$TMPDIR/restore/.cache/temp"
      test ! -e "$TMPDIR/restore/.local/share/Steam/steamapps/game"
      test ! -e "$TMPDIR/restore/mnt/remote"
      touch "$out"
    ''
