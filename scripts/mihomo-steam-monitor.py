#!/usr/bin/env python3
"""Record Steam connections that mihomo sends through a proxy node.

Polls the mihomo controller's /connections endpoint and appends each new
(host or destination, port, process, node) combination to a TSV file, and
prints it. A connection is recorded when its node is not DIRECT and it looks
Steam-related by host, by process name, or by executable path. --all records
every proxied connection instead.

Run it while Steam is open, then stop it with Ctrl-C:

  MIHOMO_SECRET=$(sudo cat /var/lib/mihomo/clash-secret) \
    scripts/mihomo-steam-monitor.py --out ~/steam-proxied.tsv
"""

import argparse
import datetime
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

STEAM_HOST = re.compile(
    r"steam|valve|dota|csgo|underlords|artifact|s\.team|hwcdn|qtlglb|bscstorage"
    r"|eccdnx|pinyuncloud|8686c|queniu|pphimalayan|clngaa|manlaxy|wmsj",
    re.IGNORECASE,
)
STEAM_PATH = re.compile(
    r"steam|proton|compatdata|pressure-vessel|wine|dota|gamescope|vrserver|vrmonitor",
    re.IGNORECASE,
)
COLUMNS = [
    "first_seen", "host", "destination", "port", "process", "node", "chain", "rule", "rule_payload",
]


def fetch(controller, secret):
    request = urllib.request.Request(f"http://{controller}/connections")
    if secret:
        request.add_header("Authorization", f"Bearer {secret}")
    with urllib.request.urlopen(request, timeout=5) as response:
        return json.load(response).get("connections") or []


def describe(conn):
    meta = conn.get("metadata") or {}
    chains = conn.get("chains") or []
    path = meta.get("processPath") or meta.get("process") or ""
    return {
        "host": meta.get("host") or "",
        "destination": meta.get("destinationIP") or "",
        "port": str(meta.get("destinationPort") or ""),
        "process": os.path.basename(path),
        "path": path,
        "node": chains[0] if chains else "",
        "chain": " > ".join(chains),
        "rule": conn.get("rule") or "",
        "rule_payload": conn.get("rulePayload") or "",
    }


def proxied(info):
    node = info["node"]
    return node not in ("", "DIRECT") and not node.startswith("REJECT")


def steam_related(info):
    return bool(
        STEAM_HOST.search(info["host"])
        or STEAM_PATH.search(info["path"])
        or STEAM_PATH.search(info["process"])
    )


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--out", default="steam-proxied.tsv", help="TSV file to append to")
    parser.add_argument("--controller", default="127.0.0.1:9090", help="mihomo controller host:port")
    parser.add_argument("--interval", type=float, default=1.0, help="seconds between polls")
    parser.add_argument("--all", action="store_true", help="record every proxied connection")
    args = parser.parse_args()
    secret = os.environ.get("MIHOMO_SECRET", "")

    seen = set()
    write_header = not os.path.exists(args.out) or os.path.getsize(args.out) == 0
    with open(args.out, "a", encoding="utf-8") as out:
        if write_header:
            out.write("\t".join(COLUMNS) + "\n")
        try:
            while True:
                try:
                    connections = fetch(args.controller, secret)
                except urllib.error.HTTPError as error:
                    if error.code == 401:
                        sys.exit("controller returned HTTP 401; set MIHOMO_SECRET")
                    sys.exit(f"controller returned HTTP {error.code}")
                except (urllib.error.URLError, OSError) as error:
                    print(f"controller unreachable: {error}", file=sys.stderr)
                    time.sleep(args.interval)
                    continue

                for conn in connections:
                    info = describe(conn)
                    if not proxied(info):
                        continue
                    if not args.all and not steam_related(info):
                        continue
                    key = (info["host"] or info["destination"], info["port"], info["process"], info["node"])
                    if key in seen:
                        continue
                    seen.add(key)
                    row = [
                        datetime.datetime.now().isoformat(timespec="seconds"),
                        info["host"],
                        info["destination"],
                        info["port"],
                        info["process"],
                        info["node"],
                        info["chain"],
                        info["rule"],
                        info["rule_payload"],
                    ]
                    out.write("\t".join(row) + "\n")
                    out.flush()
                    print("  ".join(row[:6]), flush=True)
                time.sleep(args.interval)
        except KeyboardInterrupt:
            print(f"stopped; {len(seen)} unique connections in {args.out}", file=sys.stderr)


if __name__ == "__main__":
    main()
