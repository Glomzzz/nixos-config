"""Offline checks for the new-mail notifier using a synthetic maildir."""

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

script = Path(sys.argv[1])
work = Path(tempfile.mkdtemp(prefix="mail-notify-"))
new = work / "new"
cur = work / "cur"
state = work / "state" / "inbox.json"
shown_log = work / "shown.jsonl"
opened_log = work / "opened.jsonl"
new.mkdir()
cur.mkdir()


def fake_program(name, body):
    """Write an executable Python stand-in for an external program."""
    path = work / name
    path.write_text(f"#!{sys.executable}\nimport json, os, subprocess, sys\n" + body)
    path.chmod(0o755)
    return path


# The fake notify-send records its arguments; a click is simulated by reporting
# the default action on stdout, as notify-send does when activated.
notify_send = fake_program(
    "notify-send",
    f"""
with open({str(shown_log)!r}, 'a') as stream:
    stream.write(json.dumps(sys.argv[1:]) + '\\n')
if os.environ.get('MAIL_NOTIFY_TEST_CLICK') and '--action=default=Open' in sys.argv:
    print('default')
""",
)
# The real unit detaches and waits for clicks; the fake runs the command inline.
systemd_run = fake_program(
    "systemd-run",
    """
args = sys.argv[1:]
subprocess.run(args[args.index('--') + 1:], check=True)
""",
)
# The fake emc records the Emacs form it was asked to run.
emc = fake_program(
    "emc",
    f"""
with open({str(opened_log)!r}, 'a') as stream:
    stream.write(json.dumps(sys.argv[1:]) + '\\n')
""",
)


def deliver(name, headers, directory=new):
    """Write a synthetic message with the given (header, value) pairs."""
    text = "".join(f"{key}: {value}\n" for key, value in headers) + "\nBody.\n"
    (directory / name).write_text(text)


def run_folders(*folders, click=False):
    """Run the notifier over (name, new_dir, state) folders; return its exit status."""
    args = []
    for name, directory, state_file in folders:
        args += ["--folder", name, str(directory), str(state_file)]
    command = [
        sys.executable,
        str(script),
        *args,
        "--notify-send",
        str(notify_send),
        "--systemd-run",
        str(systemd_run),
        "--emc",
        str(emc),
    ]
    env = dict(os.environ, MAIL_NOTIFY_TEST_CLICK="1" if click else "")
    return subprocess.run(command, env=env).returncode


def run(click=False):
    assert run_folders(("inbox", new, state), click=click) == 0


def shown():
    """Return (summary, body) for every notification sent so far."""
    if not shown_log.exists():
        return []
    return [tuple(json.loads(line)[-2:]) for line in shown_log.read_text().splitlines()]


def opened():
    """Return the Emacs forms that clicks asked to run, in order."""
    if not opened_log.exists():
        return []
    return [json.loads(line)[-1] for line in opened_log.read_text().splitlines()]


# Mail already waiting when the notifier first runs is recorded, not announced.
deliver("old.1", [("From", "Old <old@example.org>"), ("Subject", "Already waiting")])
run()
assert shown() == [], shown()
assert json.loads(state.read_text()) == ["old.1"]

# A new arrival is announced once; encoded names decode and markup is escaped.
deliver(
    "new.1",
    [
        ("From", "=?UTF-8?Q?Ren=C3=A9e?= <renee@example.org>"),
        ("Subject", "=?UTF-8?Q?Caf=C3=A9_menu?= & <urgent>"),
    ],
)
run()
assert shown() == [("New mail from Renée", "Café menu &amp; &lt;urgent&gt;")], shown()
run()
assert len(shown()) == 1, "an unchanged listing must not notify again"
assert opened() == [], "without a click, nothing opens"

# Reading a message moves it to cur/; a burst collapses into one summary whose
# click opens the folder's new mail.
(new / "new.1").rename(cur / "new.1:2,S")
for index in range(6):
    deliver(
        f"burst.{index}",
        [
            ("From", f"Batch {index} <batch{index}@example.org>"),
            ("Subject", f"Item {index}"),
        ],
    )
run(click=True)
assert shown()[1:] == [("6 new emails", "Open mu4e to read them.")], shown()
assert opened() == ['(mail/open-notified-folder "inbox")'], opened()

# A single notification's click opens its message by Message-ID, brackets removed.
deliver(
    "click.1",
    [
        ("From", "Ann <ann@example.org>"),
        ("Subject", "Tap me"),
        ("Message-ID", "<ab.1@example.org>"),
    ],
)
run(click=True)
assert shown()[-1] == ("New mail from Ann", "Tap me"), shown()
assert opened()[-1] == '(mail/open-notified-message "ab.1@example.org")', opened()

# A message without a sender or Message-ID still gets a notification; its click
# falls back to the folder.
deliver("anonymous.1", [("Subject", "No sender")])
run(click=True)
assert shown()[-1] == ("New mail", "No sender"), shown()
assert opened()[-1] == '(mail/open-notified-folder "inbox")', opened()

assert sorted(path.name for path in cur.iterdir()) == ["new.1:2,S"]

# Each watched folder keeps its own state; a broken folder does not stop the rest.
gmail = work / "gmail" / "new"
gmail.mkdir(parents=True)
gmail_state = work / "state" / "gmail.json"
missing = work / "missing" / "new"
missing_state = work / "state" / "missing.json"
before = len(shown())
deliver("gmail.old", [("From", "Old <old@example.org>"), ("Subject", "Waiting")], gmail)
assert run_folders(
    ("missing", missing, missing_state), ("gmail", gmail, gmail_state)
) == 1
assert shown()[before:] == [], "the first run for a folder only records its waiting mail"
assert json.loads(gmail_state.read_text()) == ["gmail.old"]
assert not missing_state.exists()

deliver("gmail.1", [("From", "Gmail <gmail@example.org>"), ("Subject", "Hello")], gmail)
assert run_folders(
    ("missing", missing, missing_state), ("gmail", gmail, gmail_state)
) == 1
assert shown()[before:] == [("New mail from Gmail", "Hello")], shown()

shutil.rmtree(work)
print("notify tests passed")
