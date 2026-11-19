"""Debounce the Z key for interception-tools.

A Z change is passed on only after the key has stayed in that state for
DEBOUNCE seconds, so switch bounce cannot turn one press into several. Other
events keep their order: while a Z change is pending they are held back and
written after it. Every change is eventually passed on, so a release can
never get lost and leave the key stuck down.
"""

import os
import select
import struct
import time

EV_SYN = 0
EV_KEY = 1
SYN_REPORT = 0
KEY_Z = 44
DEBOUNCE = 0.030  # seconds a Z change must hold before it is passed on

# struct input_event on 64-bit Linux: timeval, type, code, value.
EVENT = struct.Struct("llHHi")

raw = 0  # Z state last reported by the switch: 0 up, 1 down
out = 0  # Z state passed on to the system
changed = 0.0  # monotonic time of the last change to raw
held = []  # packets waiting for a pending Z change to settle


def settle(now):
    """Pass on a stable Z change, then release the events it was holding."""
    global out
    if raw != out and now - changed >= DEBOUNCE:
        out = raw
        os.write(1, EVENT.pack(0, 0, EV_KEY, KEY_Z, out))
        os.write(1, EVENT.pack(0, 0, EV_SYN, SYN_REPORT, 0))
    if raw == out:
        for packet in held:
            os.write(1, packet)
        held.clear()


def handle(packet, now):
    global raw, changed
    settle(now)
    _, _, kind, code, value = EVENT.unpack(packet)
    if kind == EV_KEY and code == KEY_Z and value in (0, 1):
        if value != raw:
            raw = value
            changed = now
    elif raw != out:
        held.append(packet)
    else:
        os.write(1, packet)
    settle(now)


def main():
    buf = b""
    while True:
        timeout = None
        if raw != out:
            timeout = max(0.0, changed + DEBOUNCE - time.monotonic())
        if select.select([0], [], [], timeout)[0]:
            data = os.read(0, 4096)
            if not data:
                return
            now = time.monotonic()
            buf += data
            while len(buf) >= EVENT.size:
                handle(buf[: EVENT.size], now)
                buf = buf[EVENT.size:]
        else:
            settle(time.monotonic())


if __name__ == "__main__":
    main()
