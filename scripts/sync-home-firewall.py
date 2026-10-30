#!/usr/bin/env python3
"""Reconcile one nftables interface set from explicitly approved NM profiles."""

import argparse
import json
import re
import subprocess
import sys


INTERFACE = re.compile(r"[A-Za-z0-9_.:-]{1,15}\Z")


def approved_interfaces(output, profiles, excluded=None):
    interfaces = set()
    for line in output.splitlines():
        uuid, separator, interface = line.partition(":")
        if (separator and uuid in profiles and interface != excluded
                and INTERFACE.fullmatch(interface) and interface not in ("lo", "tailscale0")):
            interfaces.add(interface)
    return sorted(interfaces)


def transaction(interfaces):
    commands = ["flush set inet nixos-fw home-lan-interfaces"]
    if interfaces:
        elements = ", ".join(json.dumps(interface) for interface in interfaces)
        commands.append("add element inet nixos-fw home-lan-interfaces { " + elements + " }")
    return "\n".join(commands) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--nmcli", required=True)
    parser.add_argument("--nft", required=True)
    parser.add_argument("--profile", action="append", default=[])
    parser.add_argument("--exclude-interface")
    args = parser.parse_args()
    result = subprocess.run([
        args.nmcli, "--terse", "--escape", "no", "--fields", "UUID,DEVICE",
        "connection", "show", "--active",
    ], capture_output=True, text=True, check=False)
    # A failed query closes the local set, never retains stale trust.
    interfaces = approved_interfaces(result.stdout if result.returncode == 0 else "",
                                     set(args.profile), args.exclude_interface)
    applied = subprocess.run([args.nft, "--file", "-"], input=transaction(interfaces),
                             text=True, check=False)
    if applied.returncode or result.returncode:
        print("Home-LAN interface synchronization failed; inspect NetworkManager/nftables.", file=sys.stderr)
        return 1
    print("Home-LAN firewall interfaces: " + (", ".join(interfaces) or "none"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
