"""Explicit, scoped access to OpenPGP-encrypted user credentials."""

import argparse
import json
import os
from pathlib import Path
import signal
import stat
import subprocess
import sys
import tempfile


class CredentialError(Exception):
    pass


TOKEN_VARIABLES = ("GITHUB_PAT_TOKEN", "GITHUB_TOKEN", "GH_TOKEN")


def clean_environment():
    env = os.environ.copy()
    for name in TOKEN_VARIABLES:
        env.pop(name, None)
    return env


def decrypt_section(program, secret_file, section):
    # Output only the requested object. Never log SOPS stdout/stderr: callers
    # must not accidentally expose decrypted values through error handling.
    result = subprocess.run(
        [program, "--decrypt", "--extract", f'[{json.dumps(section)}]',
         "--output-type", "json", secret_file],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=clean_environment(),
    )
    if result.returncode:
        raise CredentialError("Decryption failed; check the YubiKey, PIN/touch prompt, and public keyring.")
    try:
        data = json.loads(result.stdout)
    except (ValueError, UnicodeError):
        raise CredentialError("Invalid decrypted credential format.") from None
    if not isinstance(data, dict):
        raise CredentialError("Expected a credential object.")
    return data


def required_string(data, name):
    value = data.get(name)
    if not isinstance(value, str) or not value or any(c in value for c in "\x00\r\n"):
        raise CredentialError(f"Missing or invalid credential field: {name}.")
    return value


def private_directory(path, create=False):
    if create:
        path.mkdir(mode=0o700, exist_ok=True)
    info = path.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise CredentialError("Credential runtime directory must be a private, owned, non-symlink directory.")
    return path


def runtime_root():
    runtime = os.environ.get("XDG_RUNTIME_DIR", "")
    if not runtime or not Path(runtime).is_absolute():
        raise CredentialError("A private XDG_RUNTIME_DIR is required; refusing a persistent fallback.")
    parent = private_directory(Path(runtime))
    return private_directory(parent / "nixos-credentials", create=True)


def run_command(command, env):
    # Forward termination to the child so file credentials can be cleaned up.
    # No shell, command interpolation, credential argv, or global env mutation.
    child = subprocess.Popen(command, env=env)
    previous = {}

    def forward(signum, _frame):
        if child.poll() is None:
            try:
                child.send_signal(signum)
            except ProcessLookupError:
                pass

    try:
        for signum in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            previous[signum] = signal.signal(signum, forward)
        code = child.wait()
    finally:
        for signum, handler in previous.items():
            signal.signal(signum, handler)
    return code if code >= 0 else 128 - code


def scoped_command(args):
    command = args.command
    if command[:1] == ["--"]:
        command = command[1:]
    if not command:
        raise CredentialError("Supply a command after '--'; credentials are never printed.")
    env = clean_environment()
    if args.action == "github":
        data = decrypt_section(args.sops_program, args.secrets_file, "github")
        token = required_string(data, "pat")
        for name in ("GH_TOKEN", "GITHUB_TOKEN", "GITHUB_PAT_TOKEN"):
            env[name] = token
        return run_command(command, env)

    raise CredentialError(f"Unsupported credential action: {args.action}")


def smb_credential(args):
    root = runtime_root()
    destination = root / "mac-mini-smb.json"
    if args.action == "lock-smb":
        destination.unlink(missing_ok=True)
        return 0
    section = decrypt_section(args.sops_program, args.secrets_file, "smb")
    data = section.get("mac-mini")
    if not isinstance(data, dict):
        raise CredentialError("Missing Mac mini SMB credential object.")
    payload = {key: required_string(data, key) for key in ("username", "obscured_password")}
    fd, temporary = tempfile.mkstemp(prefix=".smb.", dir=root)
    try:
        with os.fdopen(fd, "w") as target:
            json.dump(payload, target)
        os.replace(temporary, destination)
    finally:
        Path(temporary).unlink(missing_ok=True)
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sops-program", default="sops")
    parser.add_argument("--secrets-file", required=True)
    actions = parser.add_subparsers(dest="action", required=True)
    actions.add_parser("github").add_argument("command", nargs=argparse.REMAINDER)
    actions.add_parser("unlock-smb")
    actions.add_parser("lock-smb")
    args = parser.parse_args(argv)
    try:
        if args.action == "github":
            return scoped_command(args)
        return smb_credential(args)
    except (CredentialError, OSError) as error:
        # OSError strings can contain arbitrary filenames. Keep diagnostics
        # generic rather than inadvertently reporting secret-derived data.
        message = str(error) if isinstance(error, CredentialError) else "Credential operation or command launch failed."
        print(f"user-credentials: {message}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
