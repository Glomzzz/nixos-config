"""Exercise the configured kitten with Kitty's loader and real key encoder.

Run inside `kitty +runpy`, with options and kitten_path supplied by the
emacs-terminal check. No display server or real clipboard is required.
"""

from types import SimpleNamespace
from unittest.mock import patch

from kittens.runner import create_kitten_handler
from kitty.fast_data_types import GLFW_PRESS, GLFW_RELEASE, KeyEvent
from kitty.options.utils import parse_shortcut
from kitty.window import Window

keymap = options.keyboard_modes[""].keymap
for key, action in (("c", "copy"), ("v", "paste")):
    definitions = keymap[parse_shortcut("ctrl+shift+" + key)]
    assert len(definitions) == 1
    assert definitions[0].definition == "kitten clipboard.py " + action
# Other modified keys must not accidentally acquire terminal actions.
for key in ("ctrl+c", "ctrl+v", "ctrl+tab", "ctrl+shift+left", "ctrl+shift+x"):
    assert parse_shortcut(key) not in keymap, key
for key, action in (("c", "copy_to_clipboard"), ("v", "paste_from_clipboard")):
    assert keymap[parse_shortcut("ctrl+alt+shift+" + key)][0].definition == action


class WindowProbe:
    # Exercise Kitty's encoder and send_key implementation, not a handwritten
    # CSI-u approximation. Only GUI/PTY/clipboard side effects are mocked.
    send_key = Window.send_key
    encoded_key = Window.encoded_key

    def __init__(self):
        self.flags = 0
        self.screen = SimpleNamespace(
            current_key_encoding_flags=lambda: self.flags,
            cursor_key_mode=False,
        )
        self.writes = []
        self.copies = 0

    def write_to_child(self, data):
        self.writes.append(data)

    def scroll_end(self):
        pass

    def copy_to_clipboard(self):
        self.copies += 1


window = WindowProbe()
pastes = []
boss = SimpleNamespace(window_id_map={42: window},
                       paste_from_clipboard=lambda: pastes.append(True))

with patch("kitty.window.get_options", return_value=options):
    for action, key in (("copy", "c"), ("paste", "v")):
        handler = create_kitten_handler(kitten_path, [action])
        assert handler.no_ui, "Clipboard routing must not launch an overlay"
        shortcut = parse_shortcut("ctrl+shift+" + key)
        # Each protocol flag (and combination) defers to the application.
        # Returning to zero must restore clipboard behavior in the same window.
        for flags in (*range(32), 0):
            for cursor_key_mode in (False, True):
                window.flags = flags
                window.screen.cursor_key_mode = cursor_key_mode
                window.writes.clear()
                window.copies = 0
                pastes.clear()
                handler.handle_result(None, 42, boss)
                if flags:
                    expected = [window.encoded_key(KeyEvent(
                        key=shortcut.key, mods=shortcut.mods, action=event,
                    )) for event in (GLFW_PRESS, GLFW_RELEASE)]
                    assert window.writes == [data for data in expected if data]
                    if flags == 1:
                        assert window.writes == [f"\x1b[{ord(key)};6u".encode()]
                    assert window.copies == 0 and not pastes
                else:
                    assert not window.writes, "Clipboard shortcuts must not send Ctrl+C/V"
                    assert window.copies == (action == "copy")
                    assert len(pastes) == (action == "paste")
        # A closed/missing target must not act on another focused window.
        window.writes.clear()
        window.copies = 0
        pastes.clear()
        handler.handle_result(None, 99, boss)
        assert not window.writes and not window.copies and not pastes

print("Clipboard shortcuts: legacy copy/paste, protocol forwarding, reset, and closed target passed")
