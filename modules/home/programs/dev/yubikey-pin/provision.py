"""Save an existing OpenPGP USER PIN using hidden local input and SOPS.

Does not change or verify the card PIN. No plaintext file, argv, or log output
contains the PIN. Python memory and runtime files can still be swapped out.
"""

import argparse
import getpass
import hmac
import json
import os
from pathlib import Path
import resource
import subprocess
import sys
import tempfile


def encrypt_pin(program, relative_path, pin, repository):
    result = subprocess.run(
        [program, "--encrypt", "--filename-override", relative_path,
         "--input-type", "json", "--output-type", "yaml", "/dev/stdin"],
        input=json.dumps({"openpgp_user_pin": pin}).encode(),
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=repository,
        check=False,
    )
    if result.returncode or not result.stdout.startswith(b"openpgp_user_pin: ENC[AES256_GCM,"):
        raise ValueError("SOPS encryption failed; the PIN was not saved.")
    return result.stdout


def save_ciphertext(target, ciphertext, replace=False):
    if target.is_symlink() or target.exists() and not replace:
        raise ValueError("Target already exists; use --replace explicitly to update it.")
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=target.parent, prefix=".yubikey-pin-", delete=False) as output:
            temporary = Path(output.name)
            output.write(ciphertext)
            output.flush()
            os.fsync(output.fileno())
        if replace:
            os.replace(temporary, target)
        else:
            # An atomic no-clobber install; the temporary file is ciphertext only.
            os.link(temporary, target)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main(argv=None):
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sops-program", required=True)
    parser.add_argument("--hostname", required=True)
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--replace", action="store_true")
    args = parser.parse_args(argv)
    try:
        if not sys.stdin.isatty() or not sys.stderr.isatty():
            raise ValueError("Run in a local terminal; refusing non-TTY PIN input.")
        repository = args.repo.resolve()
        if not (repository / ".sops.yaml").is_file() or not (repository / "flake.nix").is_file():
            raise ValueError("Run from the private nixos-secrets repository, or supply --repo.")
        relative = f"secrets/hosts/{args.hostname}-yubikey-pin.yaml"
        target = repository / relative
        if target.is_symlink() or target.exists() and not args.replace:
            raise ValueError("Encrypted PIN already exists; use --replace explicitly to update it.")
        print("Enter the CURRENT OpenPGP USER PIN, not the admin or FIDO PIN.")
        print("This does not change the card PIN. The laptop will be able to decrypt the saved PIN.")
        pin = getpass.getpass("OpenPGP user PIN (hidden): ")
        raw = pin.encode("utf-8")
        if not 6 <= len(raw) <= 127 or any(c < 32 or c == 127 for c in raw):
            raise ValueError("Expected a 6–127-byte UTF-8 PIN without control characters.")
        confirmation = getpass.getpass("Confirm OpenPGP user PIN (hidden): ").encode("utf-8")
        if not hmac.compare_digest(raw, confirmation):
            raise ValueError("PIN entries did not match; nothing was saved.")
        ciphertext = encrypt_pin(args.sops_program, relative, pin, repository)
        save_ciphertext(target, ciphertext, args.replace)
        print(f"Saved ciphertext only to {target}")
        print("Build/test and activate NixOS to install the restricted runtime secret.")
        return 0
    except (OSError, ValueError):
        # No subprocess stderr/exception details: these can contain secret input.
        print("PIN was not saved. Check the terminal, matching PIN entries, SOPS rules, and --replace if updating.", file=sys.stderr)
        return 1
    except (KeyboardInterrupt, EOFError):
        print("Cancelled; PIN was not saved.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
