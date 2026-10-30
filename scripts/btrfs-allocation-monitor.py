#!/usr/bin/env python3
"""Read Btrfs allocation counters and report pressure without changing the filesystem."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time


GIB = 1024 ** 3


def number(path):
    value = int(path.read_text().strip())
    if value < 0:
        raise ValueError("Negative filesystem counter")
    return value


def allocation(root):
    # sysfs device sizes use 512-byte sectors; disk_total already includes DUP.
    device_bytes = sum(number(device / "size") * 512 for device in (root / "devices").iterdir())
    allocated = sum(number(root / "allocation" / kind / "disk_total")
                    for kind in ("data", "metadata", "system"))
    metadata = root / "allocation" / "metadata"
    total = number(metadata / "total_bytes")
    if not total or not device_bytes:
        raise ValueError("Filesystem size is zero")
    return {
        "unallocated": max(0, device_bytes - allocated),
        "metadata_percent": 100 * number(metadata / "bytes_used") / total,
    }


def warnings(metrics):
    result = []
    if metrics["metadata_percent"] >= 80:
        result.append(f'Metadata is {metrics["metadata_percent"]:.0f}% used')
    if metrics["unallocated"] < 10 * GIB:
        result.append(f'Device unallocated is {metrics["unallocated"] / GIB:.1f} GiB')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--uuid", required=True)
    parser.add_argument("--sysfs-root", type=Path, default=Path("/sys/fs/btrfs"))
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--notify-program", required=True)
    args = parser.parse_args()
    try:
        metrics = allocation(args.sysfs_root / args.uuid)
        messages = warnings(metrics)
        print(json.dumps(metrics), flush=True)
        if not messages:
            args.state.unlink(missing_ok=True)
            return 0
        message = "; ".join(messages)
        print("Btrfs allocation warning: " + message, flush=True)
        previous = json.loads(args.state.read_text()) if args.state.exists() else {}
        now = time.time()
        if previous.get("message") == message and now - previous.get("time", 0) < 86400:
            return 0
        # Without a desktop bus the journal remains the alert, and a future run
        # retries delivery rather than recording a notification that was not sent.
        bus = Path(f"/run/user/{os.getuid()}/bus")
        if bus.exists():
            result = subprocess.run([
                args.notify_program, "--urgency=critical", "Btrfs allocation warning",
                message + ". Review docs/recovery.md before reclaiming space.",
            ], check=False)
            if result.returncode == 0:
                args.state.write_text(json.dumps({"message": message, "time": now}))
        return 0
    except (OSError, ValueError):
        print("Btrfs allocation counters/state could not be read; inspect this service.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
