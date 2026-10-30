#!/usr/bin/env python3
"""Remove persistent access-token assignments without copying their values."""

import os
from pathlib import Path
import re
import stat
import sys
import tempfile


ASSIGNMENT = re.compile(rb"^[ \t]*(?:extra-)?access-tokens[ \t]*=")


def scrub(path):
    try:
        info = path.lstat()
    except FileNotFoundError:
        return
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
        raise ValueError("Nix user config must be an owned regular file, not a symlink.")
    with path.open("rb") as source:
        if os.fstat(source.fileno()).st_ino != info.st_ino:
            raise ValueError("Nix user config changed while opening it; retry activation.")
        original = source.read()
    kept = []
    dropping = False
    for line in original.splitlines(keepends=True):
        if dropping or ASSIGNMENT.match(line):
            dropping = line.rstrip(b"\r\n").endswith(b"\\")
        else:
            kept.append(line)
    cleaned = b"".join(kept)
    if cleaned == original:
        return
    fd, name = tempfile.mkstemp(prefix=".nix-conf.", dir=path.parent)
    temporary = Path(name)
    try:
        with os.fdopen(fd, "wb") as destination:
            destination.write(cleaned)
            destination.flush()
            os.fsync(destination.fileno())
        current = path.lstat()
        if (current.st_dev, current.st_ino, current.st_mtime_ns) != (
            info.st_dev, info.st_ino, info.st_mtime_ns
        ):
            raise ValueError("Nix user config changed during cleanup; retry activation.")
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)
    print("Removed persistent Nix access-token assignments; no credential backup was created.")


def main():
    if len(sys.argv) != 2:
        print("usage: remove-nix-access-tokens.py CONFIG_FILE", file=sys.stderr)
        return 2
    try:
        scrub(Path(sys.argv[1]))
    except ValueError as error:
        print(str(error), file=sys.stderr)
        return 1
    except OSError:
        print("Could not clean the Nix user config; no credential values were logged.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
