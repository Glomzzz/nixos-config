# Terminal Emacs

Kitty is the default terminal. Foot remains installed and configured as a
fallback; it is also the second choice for desktop entries with `Terminal=true`.
Niri's `Mod+/`, Fuzzel, and the Waybar mixer/network launchers use Kitty.

## Fonts and input

`modules/home/shell/kitty.nix` sets:

- **Cascadia Mono NF, 16 pt** for ordinary text, matching GUI Emacs.
- **LXGW WenKai** for Han, Bopomofo, and Chinese punctuation.
- **Noto Color Emoji** for emoji and **Symbols Nerd Font Mono** for icon ranges.
- Native Wayland IME support, keeping Fcitx5 available for Chinese input.
- True color, without contrast-based recoloring of application faces.

The terminal owns these fonts. Emacs' GUI fontsets, variable-pitch faces, and
per-buffer font zoom cannot configure a terminal's cell font. Complex emoji
sequences can still have width/cursor limitations in Emacs 31.

Kitty's default keyboard shortcuts are cleared so Ctrl/Alt/Shift combinations,
Ctrl+Tab, and modified arrows can reach Emacs. Terminal actions instead use
**Ctrl+Alt+Shift**:

| Chord | Action |
| --- | --- |
| Ctrl+Alt+Shift+C / V | Copy terminal selection / paste clipboard |
| Ctrl+Alt+Shift+= / - | Increase / decrease this window's font size |
| Ctrl+Alt+Shift+0 | Reset font size |
| Ctrl+Alt+Shift+Enter | New terminal window in the current directory |
| Ctrl+Alt+Shift+F5 / F6 | Reload / inspect Kitty configuration |

These few terminal chords and compositor shortcuts are still reserved; no
terminal can forward keys the compositor intercepts. Hold Shift while dragging
to select terminal text when Emacs has captured the mouse. Otherwise clicks,
selection, and wheel input go to Emacs.

## Emacs side

The separate source configuration at `~/.config/emacs/` owns TTY behavior in
`modules/ui/tty.el` and keyboard negotiation through the existing KKP package.

Terminal Emacs is the default editor:

- `emc` or `emc file` opens a blocking TTY client, even on a graphical desktop.
- `EDITOR`, `VISUAL`, `SUDO_EDITOR`, and Git's editor use `emc`.
- Niri **Mod+Return** opens terminal Emacs; **Mod+E** opens terminal Dirvish.
- The Emacs desktop launcher and existing file associations use a Kitty TTY.
- **`emc -c`** explicitly opens a GUI frame; add `-n` to return immediately.
  The application menu also offers **Emacs (GUI)**.

When launched without a TTY, the managed `emc` wrapper opens Kitty and waits
for editing to finish. Never use `--no-wait` for TTY sessions: the terminal
must stay alive. `--eval`, `--help`, and `--version` do not open a terminal.
The raw `emacs` executable remains unchanged for batch/daemon/standalone use.
Existing shells keep their inherited editor variables until refreshed; Niri
uses the new values for processes spawned after its configuration reloads.

The stale-config restart guard counts both GUI and TTY frames and preserves
modified files and background mail sends. An unanswered probe against an
active service fails safely rather than restarting a possibly busy editor.

Inside terminal Emacs:

- `M-x tty/describe` reports colors, mouse, clipboard, and child-frame support.
- `M-x kkp-status` checks Kitty keyboard protocol negotiation; `C-h k` checks
  the actual key Emacs receives.
- `M-w`, `C-w`, and `C-y` use the local desktop clipboard through xclip's
  Wayland backend. GUI frames retain their native clipboard integration.
- Corfu uses **Emacs 31's native TTY child frames**, including popup info.
  No `corfu-terminal` shim is needed.
- `M-x eldoc-doc-buffer` shows full documentation in a readable window.
- `M-x kitty-graphics-mode` enables optional image/PDF support; run
  `M-x kitty-graphics-doctor` to inspect it. Enable it before opening an image
  or a PDF in DocView. It remains **off by default**.
- `M-x kitty-graphics-org-heading-sizes` separately enables enlarged Org
  headings for reading. Keep it off for intensive editing.

The optional graphics package is pinned to its v1.4.0 tag through the Emacs
package bootstrap, not Nix. ImageMagick, Ghostscript, and libsixel are supplied
here. Video, the experimental embedded browser, and automatic scaled headings
are not enabled. Third-party terminal graphics have redisplay/tmux limitations;
this is not complete GUI parity.

Kitty remote control remains disabled. Terminal clipboard writes are allowed,
but protocol-based clipboard reads still require confirmation. The local
Wayland clipboard helper does not need to enable remote clipboard reads.

## Daemon colors

`modules/home/programs/emacs/service.nix` supplies Kitty's terminfo database
and Foot's database as a fallback, while retaining ncurses' standard search
paths. A systemd daemon does not inherit a client's `TERMINFO`; the older system
Foot definition lacks `Tc`, causing Emacs to approximate theme colors unless
its own database is preferred. Do not globally force `TERM` or `COLORTERM`:
ordinary limited-color clients must retain their real capabilities.

## Validation

```sh
nix build .#checks.x86_64-linux.emacs-terminal .#checks.x86_64-linux.emacs-launchers
emacs --batch -Q -l ~/.config/emacs/tests/run.el
sh ~/.config/emacs/tests/launcher-tests.sh
```

The Nix check parses the generated configuration using Kitty's actual parser,
then starts a clean, display-less daemon and real pseudo-terminal clients. It
verifies 24-bit output for Kitty and Foot and 256-color behavior for an ordinary
xterm client. The launcher check uses mocked clients/services in real PTYs to
verify frontend selection, blocking behavior, desktop handoff, and safe restart
handling. The Emacs suite checks startup laziness, GUI isolation, terminal
setup, clipboard policy, restart guards, and the optional graphics declaration. Actual font
appearance, IME candidate placement, and interactive graphics still require a
real Wayland terminal session to assess.
