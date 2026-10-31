"""Notify about newly delivered INBOX messages.

mbsync delivers unread messages into INBOX/new and moves them to cur/ once
they are read.  After each successful sync, this lists new/, announces the
names it has not announced before, and records the listing.  It reads message
headers only and never touches mu's database.
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
    """Return the sender's name (or address) and the subject from the headers."""
    with path.open("rb") as stream:
        message = BytesParser(policy=email.policy.default).parse(
            stream, headersonly=True
        )
    addresses = getattr(message.get("From"), "addresses", ())
    sender = ""
    if addresses:
        sender = addresses[0].display_name or addresses[0].addr_spec
    subject = " ".join(str(message.get("Subject", "")).split())
    return " ".join(sender.split()), subject or "(no subject)"


def notify(program, summary, body):
    # Notification daemons render Pango markup, so message text is escaped.
    result = subprocess.run(
        [
            program,
            "--app-name=Mail",
            "--icon=mail-unread",
            html.escape(summary, quote=False),
            html.escape(body[:MAX_BODY], quote=False),
        ],
        check=False,
    )
    if result.returncode:
        print(f"notify-send exited with status {result.returncode}", file=sys.stderr)


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


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--new-dir", type=Path, required=True)
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--notify-send", required=True)
    args = parser.parse_args(argv)

    current = {path.name: path for path in args.new_dir.iterdir() if path.is_file()}
    seen = read_seen(args.state)
    if seen is None:
        # The first run only records mail that is already waiting.
        write_seen(args.state, current)
        return 0

    fresh = sorted(
        (path for name, path in current.items() if name not in seen), key=arrival
    )
    if len(fresh) > MAX_SEPARATE:
        notify(args.notify_send, f"{len(fresh)} new emails", "Open mu4e to read them.")
    else:
        for path in fresh:
            try:
                sender, subject = headline(path)
            except OSError:
                continue  # Moved by another client after the listing.
            summary = f"New mail from {sender}" if sender else "New mail"
            notify(args.notify_send, summary, subject)
    write_seen(args.state, current)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
