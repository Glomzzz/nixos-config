# Zed settings rollback snapshot

- Live source: `/home/glom/.config/zed/settings.json`
- Snapshot date: 2026-03-24
- SHA-256: `b3d3b49b85c34fdc0aa6087344b86a90739f1af1e5d334af94f2cfd6f152481a`
- Purpose: preserve the exact unmanaged file content before removing the obsolete live file after equivalence was proven against `modules/home/programs/dev/editor/zed.nix`

```jsonc
// Zed settings
//
// For information on how to configure Zed, see the Zed
// documentation: https://zed.dev/docs/configuring-zed
//
// To see all of Zed's default settings without changing your
// custom settings, run `zed: open default settings` from the
// command palette (cmd-shift-p / ctrl-shift-p)
{
  "edit_predictions": {
    "provider": "none",
  },
  "agent_servers": {
    "opencode": {
      "type": "registry",
    },
  },
  "terminal": {
    "shell": {
      "program": "nu",
    },
  },
  "agent_buffer_font_size": 16.0,
  "ui_font_family": "Monocraft",
  "buffer_font_family": "Monocraft",
  "icon_theme": "Material Icon Theme",
  "agent": {
    "favorite_models": [],
    "inline_assistant_model": {
      "provider": "copilot_chat",
      "model": "gpt-4o",
      "enable_thinking": false,
    },
    "model_parameters": [],
  },
  "telemetry": {
    "diagnostics": false,
    "metrics": false,
  },
  "session": {
    "trust_all_worktrees": true,
  },
  "vim_mode": false,
  "base_keymap": "JetBrains",
  "ui_font_size": 17.0,
  "buffer_font_size": 16.0,
  "theme": {
    "mode": "system",
    "light": "One Light",
    "dark": "Catppuccin Macchiato",
  },
  "lsp": {
    "tinymist": {
      "settings": {
        "exportPdf": "onSave",
        "outputPath": "$root/$name",
        "rootPath": "$root/root/",
      },
    },
  },
}
```
