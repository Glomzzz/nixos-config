"""Notify about newly delivered messages in the watched folders.

mbsync delivers unread messages into each folder's new/ and moves them to cur/
once they are read.  After each successful sync, this lists every watched new/
directory, announces the names it has not announced before, and records the
listing per folder.  It reads message headers only and never touches mu's
database.

Clicking a notification opens its message in mu4e, or the folder's new mail for
a summary.  Each notification runs in a transient systemd user unit that waits
for the click, so this run does not wait for notifications to be dismissed.
"""

import argparse
import email.policy
import html
import json
import os
import subprocess
import sys
from email.parser import BytesParser
from pathlib import Path

# More arrivals than this in one sync become a single summary notification.
MAX_SEPARATE = 5
MAX_BODY = 200


def headline(path):
    """Return the sender's name (or address), the subject and the Message-ID."""
    with path.open("rb") as stream:
        message = BytesParser(policy=email.policy.default).parse(
            stream, headersonly=True
        )
    addresses = getattr(message.get("From"), "addresses", ())
    sender = ""
    if addresses:
        sender = addresses[0].display_name or addresses[0].addr_spec
    subject = " ".join(str(message.get("Subject", "")).split())
    msgid = str(message.get("Message-ID", "")).strip()
    msgid = msgid.removeprefix("<").removesuffix(">").strip()
    return " ".join(sender.split()), subject or "(no subject)", msgid


def elisp_string(text):
    """Return TEXT as an Emacs Lisp string literal."""
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def read_seen(path):
    """Return the names recorded by the previous run, or None before the first run."""
    try:
        return set(json.loads(path.read_text()))
    except FileNotFoundError:
        return None
    except (TypeError, ValueError):
        print(f"ignoring unreadable state file {path}", file=sys.stderr)
        return None


def write_seen(path, names):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(sorted(names)))
    os.replace(temporary, path)


def arrival(path):
    try:
        return path.stat().st_mtime
    except OSError:
        return 0.0


def post(args, summary, body, open_form):
    """Start a transient unit that shows one notification and waits for its click."""
    command = [
        args.systemd_run,
        "--user",
        "--collect",
        "--quiet",
        "--",
        sys.executable,
        str(Path(__file__).resolve()),
        "--show",
        f"--notify-send={args.notify_send}",
        f"--emc={args.emc}",
        f"--summary={summary}",
        f"--body={body}",
        f"--open={open_form}",
    ]
    result = subprocess.run(command, check=False, capture_output=True, text=True)
    if result.returncode:
        print(
            f"mail-notify: could not start notification: {result.stderr.strip()}",
            file=sys.stderr,
        )
    return result.returncode


def show(argv):
    """Show one notification; if it is clicked, open its target in Emacs.

    Runs in the transient unit started by post(), so it may wait for the click.
    """
    parser = argparse.ArgumentParser(prog="notify.py --show")
    parser.add_argument("--notify-send", required=True)
    parser.add_argument("--emc", required=True)
    parser.add_argument("--summary", required=True)
    parser.add_argument("--body", required=True)
    parser.add_argument("--open", required=True)
    args = parser.parse_args(argv)

    # Notification daemons render Pango markup, so message text is escaped.
    result = subprocess.run(
        [
            args.notify_send,
            "--app-name=Mail",
            "--icon=mail-unread",
            "--action=default=Open",
            html.escape(args.summary, quote=False),
            html.escape(args.body[:MAX_BODY], quote=False),
        ],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode:
        print(f"notify-send exited with status {result.returncode}", file=sys.stderr)
    elif result.stdout.strip() == "default":
        # Same frame policy as the email launcher; emc starts the daemon if needed.
        subprocess.run(
            [args.emc, "--create-frame", "--no-wait", "--eval", args.open],
            check=False,
        )
    return 0


def watch(name, new_dir, state, args):
    """Announce new mail in NEW_DIR, the mu4e folder NAME; return a failure flag."""
    current = {path.name: path for path in new_dir.iterdir() if path.is_file()}
    seen = read_seen(state)
    if seen is None:
        # The first run only records mail that is already waiting.
        write_seen(state, current)
        return 0

    failed = 0
    fresh = sorted(
        (path for path_name, path in current.items() if path_name not in seen),
        key=arrival,
    )
    folder_form = f"(mail/open-notified-folder {elisp_string(name)})"
    if len(fresh) > MAX_SEPARATE:
        failed |= post(
            args, f"{len(fresh)} new emails", "Open mu4e to read them.", folder_form
        ) != 0
    else:
        for path in fresh:
            try:
                sender, subject, msgid = headline(path)
            except OSError:
                continue  # Moved by another client after the listing.
            summary = f"New mail from {sender}" if sender else "New mail"
            form = (
                f"(mail/open-notified-message {elisp_string(msgid)})"
                if msgid
                else folder_form
            )
            failed |= post(args, summary, subject, form) != 0
    write_seen(state, current)
    return failed


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if argv[:1] == ["--show"]:
        return show(argv[1:])

    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--folder",
        nargs=3,
        metavar=("NAME", "NEW_DIR", "STATE"),
        action="append",
        required=True,
        help="watch NEW_DIR, recording announced names in STATE",
    )
    parser.add_argument("--notify-send", required=True)
    parser.add_argument("--systemd-run", required=True)
    parser.add_argument("--emc", required=True)
    args = parser.parse_args(argv)

    # A failing folder (for example, a missing directory) must not stop the others.
    status = 0
    for name, new_dir, state in args.folder:
        try:
            if watch(name, Path(new_dir), Path(state), args):
                status = 1
        except OSError as error:
            print(f"mail-notify: {name}: {error}", file=sys.stderr)
            status = 1
    return status


if __name__ == "__main__":
    raise SystemExit(main())
