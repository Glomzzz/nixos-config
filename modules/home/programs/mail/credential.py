"""Read a mailbox password from GNOME's encrypted Login keyring.

Lookup/check never call unlock(), create a collection, or fall back to GPG.
Only explicit store/import-pass actions can modify the credential.
"""

import argparse
from contextlib import closing
import getpass
import os
from pathlib import Path
import subprocess
import sys

import secretstorage

LOGIN_COLLECTION = "/org/freedesktop/secrets/collection/login"
ENCRYPTED_MAGIC = b"GnomeKeyring\n\r\0\n"


class CredentialError(Exception):
    """An actionable error containing no credential material."""


def validate_password(raw):
    password = raw.rstrip(b"\r\n")
    if not password or any(char in password for char in (b"\r", b"\n", b"\0")):
        raise CredentialError("The mailbox password must be one non-empty line.")
    return password


def require_encrypted_keyring():
    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    path = data_home / "keyrings/login.keyring"
    try:
        with path.open("rb") as source:
            encrypted = source.read(16).startswith(ENCRYPTED_MAGIC)
    except OSError:
        encrypted = False
    if not encrypted:
        raise CredentialError(
            "An encrypted Login keyring is required. Set a non-empty Login "
            "keyring password in Passwords and Keys (seahorse); do not recreate it."
        )


def read_secret(collection, attributes):
    items = list(collection.search_items(attributes))
    if len(items) != 1:
        raise CredentialError(
            "Mailbox credential missing or ambiguous; run infomaniak-password "
            "store (or import-pass) in a terminal."
        )
    return validate_password(items[0].get_secret())


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--account", required=True)
    parser.add_argument("--pass-program", default="pass")
    parser.add_argument("--password-store")
    parser.add_argument(
        "action", nargs="?", default="check",
        choices=("lookup", "check", "store", "import-pass"),
    )
    args = parser.parse_args(argv)
    attributes = {
        "application": "nixos-mail",
        "service": "infomaniak",
        "account": args.account,
    }
    try:
        require_encrypted_keyring()
        with closing(secretstorage.dbus_init()) as connection:
            collection = secretstorage.Collection(connection, LOGIN_COLLECTION)
            if collection.is_locked():
                raise CredentialError(
                    "Login keyring is locked; unlock it in Passwords and Keys "
                    "or sign in with your login/keyring password."
                )
            if args.action in ("lookup", "check"):
                password = read_secret(collection, attributes)
                if args.action == "lookup":
                    sys.stdout.buffer.write(password + b"\n")
            else:
                if args.action == "store":
                    if not sys.stdin.isatty():
                        raise CredentialError("Run store interactively in a terminal.")
                    password = validate_password(
                        getpass.getpass("Infomaniak mailbox device password: ").encode()
                    )
                else:
                    environment = os.environ.copy()
                    if args.password_store:
                        environment["PASSWORD_STORE_DIR"] = args.password_store
                    result = subprocess.run(
                        [args.pass_program, "show", "email/infomaniak"],
                        env=environment, capture_output=True, check=False,
                    )
                    if result.returncode:
                        raise CredentialError(
                            "pass could not decrypt the mailbox password. Unlock "
                            "the YubiKey and retry; nothing was stored."
                        )
                    password = validate_password(result.stdout)
                collection.create_item(
                    f"Infomaniak mail: {args.account}", attributes, password,
                    replace=True, content_type="text/plain",
                )
                print("Mailbox password stored in the encrypted Login keyring.",
                      file=sys.stderr)
        return 0
    except CredentialError as error:
        print(f"Mail credential unavailable: {error}", file=sys.stderr)
    except (secretstorage.exceptions.SecretStorageException, OSError, ValueError) as error:
        # Do not dump library exceptions, subprocess output, or secret payloads.
        print(f"Cannot access the Login keyring ({type(error).__name__}). "
              "Check Passwords and Keys (seahorse).", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
