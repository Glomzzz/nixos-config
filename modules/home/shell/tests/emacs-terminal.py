"""Check Kitty settings and a display-less Emacs daemon's terminal colors."""

import fcntl
import json
import os
from pathlib import Path
import pty
import select
import struct
import subprocess
import sys
import tempfile
import termios
import time

settings = json.loads(Path(sys.argv[1]).read_text())
assert settings["terminal"] == "kitty"
assert settings["desktopTerminals"] == ["kitty.desktop", "foot.desktop"]

# Use the actual installed Kitty parser, without starting a GUI or enabling
# remote control. Unknown settings and malformed font maps must fail the check.
parser = f"""
from kitty.config import load_config
bad = []
options = load_config({settings['kittyConfig']!r}, accumulate_bad_lines=bad)
assert not bad, bad
assert options.font_family == 'Cascadia Mono NF', options.font_family
assert options.font_size == 15
assert options.wayland_enable_ime
assert options.clear_all_shortcuts
assert not options.allow_remote_control
assert options.text_fg_override_threshold == 0
assert options.symbol_map
assert 'read-clipboard' not in options.clipboard_control
assert 'read-clipboard-ask' in options.clipboard_control
# Ordinary Kitty windows still confirm before closing a running program.
assert options.confirm_os_window_close[0] == -1
emacs_options = load_config({settings['kittyConfig']!r},
    overrides=('confirm_os_window_close 0',), accumulate_bad_lines=bad)
assert not bad, bad
assert emacs_options.confirm_os_window_close[0] == 0
assert not emacs_options.allow_remote_control
print('Kitty configuration parsed; fonts, IME, keys, clipboard and scoped close policy passed')
"""
subprocess.run([settings["kitty"], "+runpy", parser], check=True)

with tempfile.TemporaryDirectory(prefix="emacs-terminal-") as directory:
    socket = str(Path(directory) / "server")
    environment = os.environ.copy()
    environment.update(HOME=directory, TERM="dumb")
    for key in ("COLORTERM", "TERMINFO", "TERMINFO_DIRS", "DISPLAY", "WAYLAND_DISPLAY"):
        environment.pop(key, None)
    environment.update(entry.split("=", 1) for entry in settings["environment"])

    def evaluate(expression):
        return subprocess.check_output(
            [settings["client"], "--socket-name=" + socket,
             "--alternate-editor=false", "--eval", expression],
            text=True, stderr=subprocess.DEVNULL, timeout=5,
        ).strip()

    def stop(process):
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)

    with open(Path(directory) / "daemon.log", "w+") as log:
        daemon = subprocess.Popen(
            [settings["emacs"], "-Q", "--fg-daemon=" + socket],
            env=environment, stdin=subprocess.DEVNULL, stdout=log, stderr=log,
        )
        try:
            deadline = time.monotonic() + 15
            while not Path(socket).exists():
                if daemon.poll() is not None or time.monotonic() > deadline:
                    log.seek(0)
                    raise AssertionError(log.read())
                time.sleep(0.05)
            evaluate("""(progn
              (custom-set-faces
               '(default ((t (:foreground "#e4e4ef" :background "#181818")))))
              (setq xterm-query-timeout 0.05))""")

            # Kitty and Foot must both work, while ordinary 256-color clients
            # must not be forced into true color by a global COLORTERM override.
            for terminal, expected in (("xterm-kitty", 16777216),
                                       ("foot", 16777216),
                                       ("xterm-256color", 256)):
                master, slave = pty.openpty()
                device = os.ttyname(slave)
                fcntl.ioctl(slave, termios.TIOCSWINSZ,
                            struct.pack("HHHH", 30, 100, 0, 0))

                def controlling_terminal():
                    os.setsid()
                    fcntl.ioctl(0, termios.TIOCSCTTY, 0)

                client = subprocess.Popen(
                    [settings["client"], "--socket-name=" + socket,
                     "--alternate-editor=false", "--tty"],
                    stdin=slave, stdout=slave, stderr=slave,
                    env=dict(environment, TERM=terminal, COLORTERM="truecolor"),
                    preexec_fn=controlling_terminal,
                )
                os.close(slave)
                frame = f'''(seq-find (lambda (f)
                    (equal (terminal-name f) "{device}")) (frame-list))'''
                try:
                    output = bytearray()
                    deadline = time.monotonic() + 0.5
                    while time.monotonic() < deadline:
                        if select.select([master], [], [], 0.05)[0]:
                            output.extend(os.read(master, 65536))
                    state = evaluate(f"""(let ((f {frame}))
                      (unless f (error "Terminal client did not connect"))
                      (list :colors (display-color-cells f)
                            :background (color-values "#181818" f)))""")
                    assert f":colors {expected}" in state, state
                    if expected == 16777216:
                        assert "(6168 6168 6168)" in state, state
                        assert any(sequence in output for sequence in (
                            b"48:2::24:24:24m", b"48:2:24:24:24m",
                            b"48;2;24;24;24m",
                        )), f"{terminal}: missing exact RGB background output"
                    print(f"{terminal}: {expected} colors; actual daemon output checked")
                finally:
                    try:
                        evaluate(f"(let ((f {frame})) (when f (delete-frame f t)))")
                    finally:
                        stop(client)
                        os.close(master)
        finally:
            try:
                evaluate("(kill-emacs)")
            except subprocess.SubprocessError:
                pass
            stop(daemon)
