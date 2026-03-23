# Editor config cleanup evidence

Verification date: 2026-03-24

## Classification cross-check

Cleanup targets were validated against `.sisyphus/evidence/editor-config-classification.md` before any deletion:

- `/home/glom/.config/zed/settings.json` is fully classified as `declarative`
- `/home/glom/.config/zed/keymap.json` is fully classified as `declarative`
- `/home/glom/.config/opencode/opencode.json` is hybrid because `provider.openai.options.apiKey` is classified as `secret`
- `/home/glom/.config/opencode/{oh-my-opencode.json,bun.lock,node_modules/,package.json,.gitignore}` remain `leave unmanaged`

## Equivalence proof used for cleanup decisions

### Zed

Conceptual comparison against `modules/home/programs/dev/editor/zed.nix` showed:

- live `settings.json` equals the managed `userSettings` payload
- live `keymap.json` equals the managed `userKeymaps` payload
- `mutableUserSettings = false` and `mutableUserKeymaps = false` mean the declarative definitions fully replace the old unmanaged files

Rollback snapshots were archived in:

- `.sisyphus/evidence/zed-settings-rollback-snapshot.md`
- `.sisyphus/evidence/zed-keymap-rollback-snapshot.md`

### OpenCode

Conceptual comparison against `modules/home/programs/dev/editor/opencode.nix` showed:

- stable live fields (`plugin`, `provider.openai.options.baseURL`, `provider.openai.models`, `agent`, `$schema`) match the managed configuration
- the live `provider.openai.options.apiKey` is still a literal secret value, while the managed module expects a secret-file reference
- the config file lives beside unmanaged runtime/project content that must remain intact

Rollback evidence was archived in `.sisyphus/evidence/opencode-config-rollback-snapshot.md` with the secret redacted and the full-file SHA-256 recorded.

## Cleanup actions taken

- Removed `/home/glom/.config/zed/settings.json`
- Removed `/home/glom/.config/zed/keymap.json`
- Did **not** remove `/home/glom/.config/opencode/opencode.json`

## Rationale for keeping `opencode.json`

This phase does not remove `/home/glom/.config/opencode/opencode.json` because safe deletion is not proven at the live filesystem level. The file still contains secret-backed behavior in its unmanaged form, and this task must not force cleanup that could change OpenCode behavior while runtime/auth/project files remain intentionally unmanaged in the same directory.

Keeping the live file is the safer reversible choice until a later verification step confirms the generated Home Manager file is the active replacement on disk and no unmanaged fallback behavior is needed.
