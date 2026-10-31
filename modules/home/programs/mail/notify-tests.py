"""Offline checks for the new-mail notifier using a synthetic maildir."""

import json
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
new.mkdir()
cur.mkdir()

# The fake notify-send records its arguments instead of contacting a daemon.
fake = work / "notify-send"
fake.write_text(
    f"#!{sys.executable}\n"
    "import json\n"
    "import sys\n"
    f"with open({str(shown_log)!r}, 'a') as stream:\n"
    "    stream.write(json.dumps(sys.argv[1:]) + '\\n')\n"
)
fake.chmod(0o755)


def deliver(name, headers, directory=new):
    """Write a synthetic message with the given (header, value) pairs."""
    text = "".join(f"{key}: {value}\n" for key, value in headers) + "\nBody.\n"
    (directory / name).write_text(text)


def run_folders(*folders):
    """Run the notifier over (name, new_dir, state) folders; return its exit status."""
    args = []
    for name, directory, state_file in folders:
        args += ["--folder", name, str(directory), str(state_file)]
    command = [sys.executable, str(script), *args, "--notify-send", str(fake)]
    return subprocess.run(command).returncode


def run():
    assert run_folders(("inbox", new, state)) == 0


def shown():
    """Return (summary, body) for every notification sent so far."""
    if not shown_log.exists():
        return []
    return [tuple(json.loads(line)[2:]) for line in shown_log.read_text().splitlines()]


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

# Reading a message moves it to cur/; a burst collapses into one summary.
(new / "new.1").rename(cur / "new.1:2,S")
for index in range(6):
    deliver(
        f"burst.{index}",
        [
            ("From", f"Batch {index} <batch{index}@example.org>"),
            ("Subject", f"Item {index}"),
        ],
    )
run()
assert shown()[1:] == [("6 new emails", "Open mu4e to read them.")], shown()

# A message without a sender still gets a notification.
deliver("anonymous.1", [("Subject", "No sender")])
run()
assert shown()[-1] == ("New mail", "No sender"), shown()

# Each watched folder keeps its own state; a broken folder does not stop the rest.
gmail = work / "gmail" / "new"
gmail.mkdir(parents=True)
gmail_state = work / "state" / "gmail.json"
missing = work / "missing" / "new"
missing_state = work / "state" / "missing.json"
before = len(shown())
deliver("gmail.old", [("From", "Old <old@example.org>"), ("Subject", "Waiting")], gmail)
assert run_folders(("missing", missing, missing_state), ("gmail", gmail, gmail_state)) == 1
assert shown()[before:] == [], "the first run for a folder only records its waiting mail"
assert json.loads(gmail_state.read_text()) == ["gmail.old"]
assert not missing_state.exists()

deliver("gmail.1", [("From", "Gmail <gmail@example.org>"), ("Subject", "Hello")], gmail)
assert run_folders(("missing", missing, missing_state), ("gmail", gmail, gmail_state)) == 1
assert shown()[before:] == [("New mail from Gmail", "Hello")], shown()

assert sorted(path.name for path in cur.iterdir()) == ["new.1:2,S"]
shutil.rmtree(work)
print("notify tests passed")
