"""Use terminal clipboard shortcuts unless the application owns extended keys."""

from kittens.tui.handler import result_handler


def main(args):
    # no_ui handlers run inside Kitty, without opening an overlay.
    pass


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    window = boss.window_id_map.get(target_window_id)
    if window is None:
        return

    action = args[1]
    if window.screen.current_key_encoding_flags():
        # Let Kitty encode the key for the application's negotiated protocol;
        # never downgrade Ctrl+Shift+C/V to Ctrl+C/V or inject literal escapes.
        window.send_key("ctrl+shift+c" if action == "copy" else "ctrl+shift+v")
    elif action == "copy":
        window.copy_to_clipboard()
    else:
        boss.paste_from_clipboard()
