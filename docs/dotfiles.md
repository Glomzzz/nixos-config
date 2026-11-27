# Dotfiles

Program configuration is versioned in this repository under `dotfiles/`. Home Manager will link it into `$HOME` once the link modules are activated. Until then the files here are staged copies only.

## Layout

- `dotfiles/pi/agent/`: pi agent configuration. `.gitignore` is default-deny: only the listed files are tracked. `models.json.tmpl` holds placeholders for the two provider base URLs. Not linked yet.
- `dotfiles/cortexkit/`: `magic-context.jsonc`, default-deny `.gitignore`. Not linked yet.
- `dotfiles/emacs/` (history import) and `dotfiles/nvim/` (deferred): not in this repository yet.

## Rules

- Never track credentials, sessions, caches, or installed packages. Runtime data stays in ignored paths.
- Credentials live in the private `nixos-secrets` repository. See `docs/secrets.md`.
- Run `just scan-staged` before committing. `just hooks` installs the same check as a pre-commit hook.
- `.gitleaksignore` lists only reviewed false positives. Add an entry only after checking the value is not a secret.

## Scan status

- `scan-secrets` on this repository: one false positive (public OpenPGP fingerprint), ignored.
- The emacs configuration repository has committed pi runtime state (`.pi/fabric/mesh/state.json`, commits `26f84fa`, `338e237`). It is excluded from the dotfiles import, but remains in that repository's public history. Its values are unclassified and need review before the rotation step.

## Pi credentials (planned)

Provider keys and base URLs are stored under `pi` in `secrets/users/glom.yaml`. Activation will decrypt them with the YubiKey and render `auth.json` and `models.json` into `$XDG_RUNTIME_DIR/pi`, with symlinks from `~/.pi/agent`. This is not implemented yet.
