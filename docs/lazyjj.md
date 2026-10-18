# lazyjj Emacs navigation

`pkgs/lazyjj.nix` applies `patches/lazyjj-emacs-keymap.patch` because lazyjj
0.6.1 only exposes configurable bindings for the log tab, not the other tabs,
details panels, or popups.

| Key | Action |
| --- | --- |
| `C-n` / `C-p` | Select the next / previous item in any tab or selection/help popup |
| `C-f` / `C-b` | Next / previous tab; move between buttons in confirmation dialogs |
| `C-v` / `M-v` | Page down / up in the details panel, or in a selection/help popup |
| `C-g` | Cancel the current popup, text entry, or confirmation; do nothing in the main view |
| `M-p` / `M-P` | Push the selected change / all bookmarks, including new bookmarks |

`C-` means Ctrl; `M-` means Alt. `M-P` is Alt+Shift+p. The old `C-p`
push binding is removed so previous-item navigation cannot push accidentally.

Text entry retains tui-textarea's native Emacs editing keys: `C-f` / `C-b`
move the cursor, and `C-n` / `C-p` move between lines rather than navigating
the application. Existing save/run keys (`C-s` / Enter, depending on the
editor), plain-key actions, arrow keys, `j` / `k`, numeric tab selection,
and `q` / Escape remain available. `C-e` / `C-y` and `C-d` / `C-u` still
scroll details by one line and half a page respectively.

The patch includes regression tests for navigation across all four tabs,
text editing, popup cancellation, empty detail panels, and safe push bindings.
They run as part of the normal lazyjj package build.

Apply with `sudo nixos-rebuild switch --flake .#nixos`, then restart lazyjj.
