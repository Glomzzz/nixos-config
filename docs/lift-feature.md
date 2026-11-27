# Lift a feature to nixos-config

`lift` moves one feature from a child configuration to its parent. Afterwards the feature is defined once, in the parent. Every profile that imports the parent gets it, and the child only imports the parent.

- Parent: `nixos-config`, repo `~/nixos-config`, remote `github:Glomzzz/nixos-config`.
- Child: `nixos-config-geekpro`, repo `/home/glom/nixos-config-geekpro`. Its flake input `nixos-config` pins the parent.
- `xxx` below is the feature name: the file basename without `.nix` (for example `python`).

This document lives in both repositories with the same content. The parent is also a jj colocated repo (`.jj/`); the steps use git, and jj sees the same commits.

## What counts as a feature

A feature is one self-contained child Nix file. The usual case is a hardware addition:

```text
hardware/<profile>/addition/<kind>/<rest>.nix
```

where `<kind>` is `nixos`, `home`, or `services/{nixos,home}`. A hardware-level file directly under `hardware/<profile>/` (for example `audio.nix`) can also be lifted, under the same rules.

Never lift:

- anything under `stepai/`, `pkgs/stepai/`, or any other company configuration. The parent is a personal repository on GitHub;
- any file that names a secret, token, key, or PIN.

## Liftability check

Before changing anything, check all four points. If any fails, stop and report the reason. Do not lift.

1. No hardware identifiers. Interface names (`wlp4s0`), output names (`HDMI-A-1`, `eDP-1`), device paths, GPU or driver choices, panel scales, and product, PCI or USB IDs are not allowed. Example: `hardware/geekpro-17irr/addition/services/nixos/aiknowledge-firewall.nix` (`wlp4s0`) and `hardware/geekpro-17irr/addition/home/desktop/niri/outputs.nix` (`HDMI-A-1`) are not liftable as they are.
2. Harmless on every profile. The parent's common layer also reaches the zephyrus laptop. The feature must not duplicate what that profile already adds. Example: `hardware/geekpro-17irr/addition/nixos/programs/android.nix` installs `android-studio`, which `hardware/zephyrus/addition/nixos/programs/android.nix` already installs, so it is not liftable as a plain new file.
3. No unplanned conflict. Grep the parent for every option name the feature sets. If the parent already sets the same option, the lift is a merge (see Placement).
4. No machine-specific wording. Rewrite header comments that say `desktop only`, `GeekPro`, or `this machine`.

## Placement in the parent

Mirror the child path and drop the `hardware/<profile>/addition/` prefix:

| Child feature path | Parent location | Import added to |
| --- | --- | --- |
| `hardware/<p>/addition/nixos/<rest>` | `modules/nixos/<rest>` | the `default.nix` that already imports its neighbours |
| `hardware/<p>/addition/home/<rest>` | `modules/home/<rest>` | the `default.nix` that already imports its neighbours |
| `hardware/<p>/addition/services/<k>/<rest>` | `modules/services/<k>/<rest>` | the `default.nix` that already imports its neighbours |
| hardware-level file (driver, firmware, kernel, input, power) | `hardware/common/<topic>.nix` | `hardware/common/default.nix` |

`hardware/common` is exported as `nixosModules.hardware-common` and imported by every profile. The `modules/` tree reaches every profile through `hosts/nixos/shared.nix` and `users/glom/home.nix`. Both count as common.

Merges: if the mirror path already exists in the parent, do not overwrite it. Add the feature's options to that file, keep its existing content, and name the merge in the parent commit body. If the merge needs `mkForce` or changes a value the parent sets, stop and ask the user.

Do not add a feature to a profile directory. Profile directories hold only what one machine needs.

## Procedure

### Preflight

```bash
git -C ~/nixos-config status --short
git -C /home/glom/nixos-config-geekpro status --short
git -C ~/nixos-config pull --ff-only
```

Both working trees must be clean. Stop if either is not.

### 1. Parent: add the feature, commit, push

1. Copy the child file to its parent location. Copy, do not move: history stays in the child commit.
2. Rewrite the header comment for a shared module.
3. Add the import line to the parent `default.nix`.
4. Format and parse: `alejandra <files>` and `nix-instantiate --parse <file>` for each new or edited file.
5. `git add` the new file and the edited `default.nix`. New files must be tracked, or the flake does not see them.
6. Commit with the parent message in the table below. The body gives the child path, the parent path, and any merge note.
7. Laptop gate, before any push. Bring the local commit to the zephyrus laptop without pushing (for example `git bundle create` here, copy the bundle, and `git pull` it into the laptop's `~/nixos-config`). Then run `just build` there. Only a successful build allows the push. If it fails, amend or revert the local commit and repeat this step.
8. `git -C ~/nixos-config push origin HEAD`. Record the new commit hash.

The parent is not evaluated on this machine. Its `nixosConfigurations` read DMI with `--impure`, so they only evaluate on the matching laptop. The laptop build in step 7 is the parent's evaluation check; the child build in step 2 checks the result after the lock moves.

### 2. Child: upgrade the lock, undo the feature, commit

1. Upgrade the parent input only:
   ```bash
   cd /home/glom/nixos-config-geekpro && just upgrade nixos-config
   ```
   This runs `nix flake update nixos-config`. Review `git diff flake.lock`. The `nixos-config` node must now point at the pushed commit. Inputs the child makes follow `nixos-config/...` (nixpkgs, home-manager, sops-nix, and others) also move. That is expected. `nixpkgs-gcc11` must not change.
2. Undo the feature:
   - `git rm` the child file;
   - remove its import line from the child `default.nix` (for hardware additions, `hardware/geekpro-17irr/default.nix`);
   - remove directories left empty.
3. Verify:
   ```bash
   just build
   grep -rn 'xxx' --include='*.nix' .
   ```
   The build must succeed. The grep must find no definition of the feature in the child. Mentions in docs are fine.
4. Commit `flake.lock` and the removed paths with the child message in the table below. The body gives the lock change, `nixos-config: <old rev> -> <new rev>`, and the parent commit hash.

The child commit is local. Do not push it unless the user asks.

### 3. Hand-off

Tell the user to deploy. Do not deploy as part of the lift:

```bash
cd /home/glom/nixos-config-geekpro && just deploy
```

`scripts/deploy.sh --switch` is the proxy-aware alternative. The zephyrus laptop receives the feature on its next pull of the parent; it should run `just build` there before deploying.

## Dependent package entries

Some features are two files: a package entry in `pkgs/` and a Home Manager or NixOS module that uses it (`pkgs.<name>`). Lift both together, or the module fails to evaluate.

- Package: copy the file to `pkgs/<name>.nix` unchanged, and add `<name> = final.callPackage ./<name>.nix {};` to `pkgs/default.nix`, in alphabetical order.
- Module: copy the module to its mirror path under `modules/` and import it from the neighbour `default.nix`.
- Child removal: remove the overlay line before deleting the package file. The overlay line calls the file, so deleting only the file breaks evaluation.
- Overlay application needs no child change: `hosts/nixos/shared.nix` imports `hosts/nixos/overlays.nix`, which applies `pkgs/` to every host.

Worked example: plannotator (`pkgs/plannotator.nix` and `modules/home/programs/dev/plannotator.nix`).

## Commit messages

| Repo | Message |
| --- | --- |
| parent | `lift(xxx): add xxx from nixos-config-geekpro` |
| child | `lift(xxx): xxx to nixos-config` |

## Rollback

- Before the child commit: `git restore --source=HEAD --staged --worktree -- flake.lock <paths>` restores the lock and the removed files.
- After the child commit, not pushed: `git revert --no-edit HEAD`. This restores the old lock and the feature file.
- After the parent is pushed: `git revert <hash>` in the parent, commit, and push. Then revert the child commit as above, build, and deploy.

## Worked example: python

Child: `hardware/geekpro-17irr/addition/nixos/programs/python.nix` installs `pkgs.python3`.

Parent:

- add `modules/nixos/programs/python.nix` with the header comment rewritten for a shared module;
- add `./python.nix` to `modules/nixos/programs/default.nix`;
- commit `lift(python): add python from nixos-config-geekpro` and push.

Child:

- `git rm hardware/geekpro-17irr/addition/nixos/programs/python.nix`;
- remove `./addition/nixos/programs/python.nix` from `hardware/geekpro-17irr/default.nix`;
- `just upgrade nixos-config`, `just build`, commit `lift(python): python to nixos-config`.

After this, the zephyrus laptop also installs `python3` on its next update. That is the intended effect of a lift.
