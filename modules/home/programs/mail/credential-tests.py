"""Offline credential-provider tests: no real keyring, card, or network."""

from contextlib import redirect_stderr, redirect_stdout
import importlib.util
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import MagicMock, patch

spec = importlib.util.spec_from_file_location("mail_credential", sys.argv.pop(1))
credential = importlib.util.module_from_spec(spec)
spec.loader.exec_module(credential)

PASSWORD = b"synthetic-offline-device-password"


class CredentialTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.keyring = Path(self.directory.name) / "keyrings/login.keyring"
        self.keyring.parent.mkdir()
        self.keyring.write_bytes(credential.ENCRYPTED_MAGIC + b"synthetic ciphertext")
        environment = patch.dict(os.environ, {"XDG_DATA_HOME": self.directory.name})
        environment.start()
        self.addCleanup(environment.stop)
        self.connection = MagicMock()
        self.collection = MagicMock()
        self.collection.is_locked.return_value = False
        self.item = MagicMock()
        self.item.get_secret.return_value = PASSWORD
        self.collection.search_items.return_value = [self.item]
        self.dbus = patch.object(credential.secretstorage, "dbus_init",
                                 return_value=self.connection).start()
        self.constructor = patch.object(credential.secretstorage, "Collection",
                                        return_value=self.collection).start()
        self.run = patch.object(credential.subprocess, "run").start()
        self.addCleanup(patch.stopall)

    def invoke(self, action="lookup", extra=()):
        stdout = io.TextIOWrapper(io.BytesIO(), encoding="utf-8", write_through=True)
        stderr = io.StringIO()
        arguments = ["--account", "test@example.org", *extra]
        if action is not None:
            arguments.append(action)
        with redirect_stdout(stdout), redirect_stderr(stderr):
            status = credential.main(arguments)
        return status, stdout.buffer.getvalue(), stderr.getvalue()

    def assert_no_unlock_or_gpg(self):
        self.collection.unlock.assert_not_called()
        self.run.assert_not_called()
        self.connection.close.assert_called_once()

    def test_lookup_reads_only_explicit_login_collection(self):
        status, stdout, stderr = self.invoke()
        self.assertEqual((status, stdout, stderr), (0, PASSWORD + b"\n", ""))
        self.constructor.assert_called_once_with(self.connection, credential.LOGIN_COLLECTION)
        self.collection.search_items.assert_called_once_with({
            "application": "nixos-mail", "service": "infomaniak", "account": "test@example.org",
        })
        self.collection.create_item.assert_not_called()
        self.assert_no_unlock_or_gpg()

    def test_check_never_prints_password(self):
        self.assertEqual(self.invoke("check"), (0, b"", ""))
        self.assert_no_unlock_or_gpg()

    def test_no_action_defaults_to_check_not_password_output(self):
        self.assertEqual(self.invoke(None), (0, b"", ""))
        self.assert_no_unlock_or_gpg()

    def test_locked_keyring_fails_without_prompt_or_password_read(self):
        self.collection.is_locked.return_value = True
        status, stdout, stderr = self.invoke("check")
        self.assertEqual((status, stdout), (1, b""))
        self.assertIn("keyring is locked", stderr)
        self.collection.search_items.assert_not_called()
        self.item.get_secret.assert_not_called()
        self.assert_no_unlock_or_gpg()

    def test_missing_or_ambiguous_items_do_not_fall_back_to_pass(self):
        for items in ([], [self.item, self.item]):
            self.collection.search_items.return_value = items
            status, stdout, stderr = self.invoke()
            self.assertEqual((status, stdout), (1, b""))
            self.assertIn("missing or ambiguous", stderr)
        self.run.assert_not_called()
        self.collection.unlock.assert_not_called()

    def test_lock_race_is_noninteractive_and_never_logs_exception_payload(self):
        self.item.get_secret.side_effect = credential.secretstorage.exceptions.LockedException(
            PASSWORD.decode()
        )
        status, stdout, stderr = self.invoke()
        self.assertEqual((status, stdout), (1, b""))
        self.assertNotIn(PASSWORD.decode(), stderr)
        self.assert_no_unlock_or_gpg()

    def test_plaintext_or_missing_keyring_refused_before_connecting(self):
        self.keyring.write_text("[keyring]\nUnencrypted=true\n")
        status, stdout, stderr = self.invoke("store")
        self.assertEqual((status, stdout), (1, b""))
        self.assertIn("encrypted Login keyring is required", stderr)
        self.keyring.unlink()
        self.assertEqual(self.invoke()[0], 1)
        self.dbus.assert_not_called()
        self.collection.create_item.assert_not_called()

    def test_store_uses_hidden_terminal_prompt_and_replaces_only_mail_entry(self):
        with patch.object(sys.stdin, "isatty", return_value=True), \
                patch.object(credential.getpass, "getpass", return_value=PASSWORD.decode()):
            status, stdout, stderr = self.invoke("store")
        self.assertEqual((status, stdout), (0, b""))
        self.assertNotIn(PASSWORD.decode(), stderr)
        self.collection.create_item.assert_called_once_with(
            "Infomaniak mail: test@example.org",
            {"application": "nixos-mail", "service": "infomaniak", "account": "test@example.org"},
            PASSWORD, replace=True, content_type="text/plain",
        )
        self.run.assert_not_called()

    def test_store_refuses_echoing_nonterminal_input(self):
        with patch.object(sys.stdin, "isatty", return_value=False), \
                patch.object(credential.getpass, "getpass") as prompt:
            self.assertEqual(self.invoke("store")[0], 1)
            prompt.assert_not_called()
        self.collection.create_item.assert_not_called()

    def test_explicit_import_pipes_password_without_printing_or_changing_pass(self):
        self.run.return_value = subprocess.CompletedProcess([], 0, PASSWORD + b"\n", b"")
        status, stdout, stderr = self.invoke("import-pass", extra=(
            "--pass-program", "/fake/bin/pass", "--password-store", "/fake/password-store",
        ))
        self.assertEqual((status, stdout), (0, b""))
        self.assertNotIn(PASSWORD.decode(), stderr)
        self.assertEqual(self.run.call_args.args[0], ["/fake/bin/pass", "show", "email/infomaniak"])
        self.assertEqual(self.run.call_args.kwargs["env"]["PASSWORD_STORE_DIR"], "/fake/password-store")
        self.assertEqual(self.collection.create_item.call_args.args[2], PASSWORD)

    def test_failed_import_cannot_store_empty_password_or_leak_subprocess_output(self):
        self.run.return_value = subprocess.CompletedProcess([], 1, PASSWORD, PASSWORD)
        status, stdout, stderr = self.invoke("import-pass")
        self.assertEqual((status, stdout), (1, b""))
        self.assertNotIn(PASSWORD.decode(), stderr)
        self.collection.create_item.assert_not_called()

    def test_import_checks_lock_before_using_yubikey(self):
        self.collection.is_locked.return_value = True
        self.assertEqual(self.invoke("import-pass")[0], 1)
        self.run.assert_not_called()
        self.collection.create_item.assert_not_called()

    def test_empty_multiline_or_nul_passwords_are_rejected(self):
        for value in (b"", b"\n", b"password\nnotes\n", b"password\0"):
            self.item.get_secret.return_value = value
            status, stdout, _ = self.invoke()
            self.assertEqual((status, stdout), (1, b""))


if __name__ == "__main__":
    unittest.main()
