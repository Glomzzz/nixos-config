# Terminal Emacs

Kitty is the default terminal. Foot remains installed and configured as a
fallback; it is also the second choice for desktop entries with `Terminal=true`.
Niri's `Mod+/`, Fuzzel, and the Waybar mixer/network launchers use Kitty.

## Fonts and input

`modules/home/shell/kitty.nix` sets:

- **Cascadia Mono NF, 15 pt** for ordinary text (GUI Emacs remains at 16 pt).
- **LXGW WenKai** for Han, Bopomofo, and Chinese punctuation.
- **Noto Color Emoji** for emoji and **Symbols Nerd Font Mono** for icon ranges.
- Native Wayland IME support, keeping Fcitx5 available for Chinese input.
- True color, without contrast-based recoloring of application faces.

The terminal owns these fonts. Emacs' GUI fontsets, variable-pitch faces, and
per-buffer font zoom cannot configure a terminal's cell font. Complex emoji
sequences can still have width/cursor limitations in Emacs 31.

Kitty's default keyboard shortcuts are cleared so Ctrl/Alt/Shift combinations,
Ctrl+Tab, and modified arrows can reach Emacs. **Ctrl+Shift+C / V** copy the
terminal selection / paste the clipboard when extended keyboard reporting is
inactive. When an application negotiates the Kitty keyboard protocol (including
terminal Emacs and Pi), the clipboard kitten forwards those keys using Kitty's
own key encoder instead: the application owns their meaning. This uses the
current window's protocol state, not its title or a process-name heuristic.

Unconditional terminal actions use **Ctrl+Alt+Shift**:

| Chord | Action |
| --- | --- |
| Ctrl+Alt+Shift+C / V | Copy terminal selection / paste clipboard |
| Ctrl+Alt+Shift+= / - | Increase / decrease this window's font size |
| Ctrl+Alt+Shift+0 | Reset font size |
| Ctrl+Alt+Shift+Enter | New terminal window in the current directory |
| Ctrl+Alt+Shift+F5 / F6 | Reload / inspect Kitty configuration |

The Ctrl+Alt+Shift chords and compositor shortcuts are still reserved; no
terminal can forward keys the compositor intercepts. Hold Shift while dragging
to select terminal text when Emacs has captured the mouse. Otherwise clicks,
selection, and wheel input go to Emacs.

## Emacs side

The separate source configuration at `~/.config/emacs/` owns TTY behavior in
`modules/ui/tty.el` and keyboard negotiation through the existing KKP package.

Terminal Emacs is the default editor:

- `emc` or `emc file` opens a blocking TTY client, even on a graphical desktop.
- `majj` opens Majutsu's change graph and working-copy status in terminal
  Emacs for the current Jujutsu workspace; `majj DIRECTORY` selects another
  workspace. Use `C-x C-c` to close the client and return to the shell without
  stopping the daemon. Majutsu is managed by `~/.config/emacs/`, not Nix.
- `EDITOR`, `VISUAL`, `SUDO_EDITOR`, and Git's editor use `emc`.
- Niri **Mod+Return** opens terminal Emacs; **Mod+E** opens terminal Dirvish.
- The Emacs desktop launcher and existing file associations use a Kitty TTY.
- **`emc -c`** explicitly opens a GUI frame; add `-n` to return immediately.
  The application menu also offers **Emacs (GUI)**.

When launched without a TTY, the managed `emc` wrapper opens Kitty and waits
for editing to finish. Never use `--no-wait` for TTY sessions: the terminal
must stay alive. `--eval`, `--help`, and `--version` do not open a terminal.

Dedicated Emacs windows use Kitty's `--override confirm_os_window_close=0`,
so **Win+Q / Mod+Q** closes them without Kitty's running-program confirmation.
This disconnects the client, not the daemon: buffers, including unsaved edits,
remain in Emacs, but are not automatically saved to disk. Desktop Emacs/Dirvish
entries use `Terminal=false` so `emc` creates this dedicated Kitty itself;
they still run terminal Emacs. Other Kitty windows retain the default close
confirmation, including an existing shell window where you manually run `emc`.

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
verifies clipboard routing and protocol key encoding, 24-bit output for Kitty
and Foot, and 256-color behavior for an ordinary xterm client. The launcher
check uses mocked clients/services in real PTYs to verify frontend selection,
blocking behavior, Majutsu directory selection, desktop handoff, and safe
restart handling. The Emacs suite checks startup laziness, GUI isolation, terminal
setup, clipboard policy, restart guards, and the optional graphics declaration. Actual font
appearance, IME candidate placement, and interactive graphics still require a
real Wayland terminal session to assess.
