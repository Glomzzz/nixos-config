# Compatibility baselines

`system.stateVersion` and `home.stateVersion` are compatibility settings, not
release selectors. Both are frozen at `26.11`; updating `flake.lock` must not
change them.

## Why the current values are retained

The repository began with NixOS `24.05`; the initial Home Manager configuration
used `24.11`. Later upgrades changed the baselines to `25.11` / `25.05`, then
`26.05`, then `26.11` (`5ce093d`, 2026-06-18). Those changes were not necessary
for package updates, but blindly reverting them now could reintroduce defaults
that no longer match persistent state.

A targeted evaluation audit against the locked nixpkgs and Home Manager found:

- Docker's selected storage driver and Syncthing's declared settings do not
  change between the `24.11` and `26.11` baselines.
- Userborn and systemd-sysusers remain disabled in both evaluations.
- XDG user directories keep the same paths, but
  `xdg.userDirs.setSessionVariables` changes from `true` to `false` at `26.05`.
  The current configuration already uses the latter behavior.

This is an evaluation audit, not proof that every on-disk service state has been
migrated correctly. Keeping the current baseline avoids a second unverified
migration. Do not reset it merely to match the original install date.

Before any future baseline change, back up data, compare defaults for enabled
services, follow their documented migrations, and test login and service data.
New hosts should choose their own initial-install baseline.
