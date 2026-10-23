"""Explicit saved-user-PIN provider with a Qt Assuan fallback.

The secret travels only from a private runtime file to gpg-agent's pipe. Prompt
matching scopes convenience behavior; it is NOT isolation from our own UID.
"""

import argparse
import fcntl
import json
import os
from pathlib import Path
import re
import resource
import stat
import subprocess
import sys
from urllib.parse import unquote_to_bytes


CARD_PROMPT = re.compile(
    rb"(?:^|\n\n)Please unlock the card\n\n\x1e?Number\x1f?: ([0-9 ]+)"
    rb"\nHolder\x1f?: [^\r\n]*(?:\nCounter\x1f?: ([0-9]+))?\Z"
)
MAX_LINE = 4096


def private_file(path, limit):
    fd = os.open(path, os.O_RDONLY | os.O_CLOEXEC | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        info = os.fstat(fd)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid():
            raise ValueError("Not a private regular file")
        if info.st_mode & 0o077 or info.st_size > limit:
            raise ValueError("Unsafe file permissions or size")
        data = os.read(fd, limit + 1)
        if len(data) > limit:
            raise ValueError("File too large")
        return data, [info.st_dev, info.st_ino, info.st_mtime_ns]
    finally:
        os.close(fd)


def valid_pin(pin):
    # Preserve spaces and UTF-8 exactly; never strip or log a secret.
    if not 6 <= len(pin) <= 127 or any(c < 32 or c == 127 for c in pin):
        return False
    try:
        pin.decode("utf-8")
    except UnicodeError:
        return False
    return True


def device_generation(usb_root, serial):
    devices = []
    for path in Path(usb_root).iterdir():
        try:
            if (path / "idVendor").read_text().strip() != "1050":
                continue
            bus = int((path / "busnum").read_text())
            device = int((path / "devnum").read_text())
            usb_serial = path / "serial"
            if usb_serial.exists() and usb_serial.read_text().strip() != serial:
                continue
            devices.append([path.name, bus, device])
        except (OSError, ValueError):
            continue
    # Some YubiKeys hide the USB serial. Do not guess between multiple devices.
    return devices[0] if len(devices) == 1 else None


def private_directory(path):
    info = path.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise ValueError("Unsafe runtime directory")


def claim_attempt(runtime, serial, generation, version, counter):
    """Persist BEFORE sending: no replay without evidence of a successful sign.

    Pinentry cannot see whether card verification succeeded. A larger signature
    counter proves a signature occurred in between. Otherwise, only replacement
    of the secret or a new USB connection permits another automatic submission.
    """
    root = Path(runtime)
    private_directory(root)
    directory = root / "yubikey-pin"
    directory.mkdir(mode=0o700, exist_ok=True)
    private_directory(directory)
    lock = os.open(directory / "lock", os.O_CREAT | os.O_RDWR | os.O_CLOEXEC | os.O_NOFOLLOW, 0o600)
    try:
        info = os.fstat(lock)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
            return False
        fcntl.flock(lock, fcntl.LOCK_EX)
        path = directory / "attempt.json"
        try:
            previous = json.loads(private_file(path, 2048)[0])
        except FileNotFoundError:
            previous = None
        identity = {"serial": serial, "device": generation, "secret_version": version}
        if previous is not None:
            if not isinstance(previous, dict) or set(previous) != {*identity, "counter"}:
                return False
            if all(previous[key] == value for key, value in identity.items()):
                old = previous["counter"]
                if counter is None or not isinstance(old, int) or counter <= old:
                    return False
        # Nonsecret state, but still private and written with no symlink following.
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_CLOEXEC | os.O_NOFOLLOW, 0o600)
        try:
            info = os.fstat(fd)
            if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
                return False
            with os.fdopen(fd, "w", closefd=False) as target:
                json.dump({**identity, "counter": counter}, target)
                target.flush()
        finally:
            os.close(fd)
        return True
    finally:
        os.close(lock)


class Request:
    def __init__(self):
        self.reset()

    def reset(self):
        self.description = b""
        self.prompt = b""
        self.keyinfo = None
        self.manual = False
        self.sent = False

    def observe(self, command, argument):
        if command == b"RESET":
            self.reset()
        elif command == b"SETDESC":
            self.description = unquote_to_bytes(argument)
        elif command == b"SETPROMPT":
            self.prompt = unquote_to_bytes(argument)
        elif command == b"SETKEYINFO":
            self.keyinfo = argument
        elif command in {b"SETERROR", b"SETREPEAT", b"SETQUALITYBAR", b"SETGENPIN"}:
            self.manual = True
        elif command == b"OPTION" and argument.startswith(b"pinentry-user-data="):
            self.manual = True

    def saved_pin(self, args):
        if self.manual or self.sent or self.prompt not in {b"PIN", b"PIN:"} or self.keyinfo != b"--clear":
            return None
        match = CARD_PROMPT.search(self.description)
        if match is None or match[1].replace(b" ", b"").decode("ascii") != args.card_serial:
            return None
        counter = int(match[2]) if match[2] is not None else None
        try:
            pin, version = private_file(args.pin_file, 127)
            if not valid_pin(pin):
                return None
            generation = device_generation(args.usb_root, args.card_serial)
            if generation is None or not args.runtime_dir:
                return None
            if not claim_attempt(args.runtime_dir, args.card_serial, generation, version, counter):
                return None
            self.sent = True
            return pin
        except (OSError, ValueError, TypeError):
            # Missing secret, low-tries/unknown prompt, or unsafe state: use Qt.
            return None


def read_line(stream):
    line = stream.readline(MAX_LINE + 1)
    if len(line) > MAX_LINE or line and not line.endswith(b"\n"):
        raise ValueError("Invalid Assuan line")
    return line


def relay_response(backend, client_in, client_out):
    while True:
        line = read_line(backend.stdout)
        if not line:
            raise OSError("Pinentry closed")
        client_out.write(line)
        client_out.flush()
        keyword = line.split(maxsplit=1)[0].upper()
        if keyword in {b"OK", b"ERR"}:
            return keyword == b"OK"
        if keyword == b"INQUIRE":
            while True:
                reply = read_line(client_in)
                if not reply:
                    raise OSError("Client closed")
                backend.stdin.write(reply)
                backend.stdin.flush()
                if reply.split(maxsplit=1)[0].upper() in {b"END", b"CAN"}:
                    break


def serve(args, extra, client_in, client_out):
    # The real Qt backend handles every normal command/inquiry and manual prompt.
    with subprocess.Popen([args.fallback, *extra], stdin=subprocess.PIPE,
                          stdout=subprocess.PIPE, stderr=subprocess.DEVNULL) as backend:
        try:
            relay_response(backend, client_in, client_out)
            request = Request()
            while line := read_line(client_in):
                command, _, argument = line.rstrip(b"\r\n").partition(b" ")
                command = command.upper()
                if command == b"GETINFO" and argument == b"pid":
                    # GPG must monitor this provider, not just its Qt child.
                    client_out.write(f"D {os.getpid()}\nOK\n".encode())
                    client_out.flush()
                    continue
                if command == b"GETPIN":
                    pin = request.saved_pin(args)
                    if pin is not None:
                        escaped = pin.replace(b"%", b"%25").replace(b"\r", b"%0D").replace(b"\n", b"%0A")
                        client_out.write(b"D " + escaped + b"\nOK\n")
                        client_out.flush()
                        continue
                # Even if enabled globally, do not let Qt cache other passwords.
                if command == b"OPTION" and argument == b"allow-external-password-cache":
                    client_out.write(b"OK\n")
                    client_out.flush()
                    continue
                backend.stdin.write(line)
                backend.stdin.flush()
                if relay_response(backend, client_in, client_out):
                    request.observe(command, argument)
                if command == b"BYE":
                    break
        finally:
            if backend.poll() is None:
                backend.terminate()
            try:
                backend.wait(timeout=2)
            except subprocess.TimeoutExpired:
                backend.kill()
                backend.wait()


def main():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fallback", required=True)
    parser.add_argument("--card-serial", required=True)
    parser.add_argument("--pin-file", default="/run/secrets/yubikey/openpgp-user-pin")
    parser.add_argument("--runtime-dir", default=os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    parser.add_argument("--usb-root", default="/sys/bus/usb/devices")
    args, extra = parser.parse_known_args()
    try:
        serve(args, extra, sys.stdin.buffer, sys.stdout.buffer)
        return 0
    except (OSError, ValueError):
        # Clients can close without reading BYE's response. Discard pending
        # output on EPIPE instead of producing an interpreter-shutdown traceback.
        try:
            sys.stdout.buffer.write(b"ERR 83886179 PIN entry unavailable\n")
            sys.stdout.buffer.flush()
        except OSError:
            null = os.open(os.devnull, os.O_WRONLY)
            try:
                os.dup2(null, sys.stdout.fileno())
            finally:
                os.close(null)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
