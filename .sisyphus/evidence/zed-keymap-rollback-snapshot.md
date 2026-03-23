# Zed keymap rollback snapshot

- Live source: `/home/glom/.config/zed/keymap.json`
- Snapshot date: 2026-03-24
- SHA-256: `b4d4279e644f979bd9242ac7e2603f870d2593e4ef2cc129e6e9952b8dee0ceb`
- Purpose: preserve the exact unmanaged file content before removing the obsolete live file after equivalence was proven against `modules/home/programs/dev/editor/zed.nix`

```jsonc
// Zed keymap
//
// For information on binding keys, see the Zed
// documentation: https://zed.dev/docs/key-bindings
//
// To see the default key bindings run `zed: open default keymap`
// from the command palette.
[
  {
    "context": "Workspace",
    "bindings": {
      // "shift shift": "file_finder::Toggle"
    },
  },
  {
    "context": "Editor && vim_mode == insert",
    "bindings": {
      // "j k": "vim::NormalBefore"
    },
  },
  {
    "context": "AcpThread > (Editor && !use_modifier_to_send)",
    "bindings": {
      "enter": null
    }
  },
  {
    "context": "Editor",
    "bindings": {
      "shift-r": "editor::Rename"
    }
  },
  {
    "context": "Editor",
    "bindings": {
      "shift-f6": null
    }
  },
  {
    "context": "ProjectPanel",
    "bindings": {
      "shift-r": "project_panel::Rename"
    }
  },
  {
    "context": "ProjectPanel",
    "bindings": {
      "shift-f6": null
    }
  }
]
```
