"""Tests use fake credentials, no hardware, real secrets, or network access."""

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import signal
import stat
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("credentials", sys.argv.pop(1))
credentials = importlib.util.module_from_spec(spec)
spec.loader.exec_module(credentials)

FAKE = "fake-test-only-secret"


class CredentialsTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.runtime = Path(self.directory.name)
        self.environment = patch.dict(os.environ, {
            "XDG_RUNTIME_DIR": str(self.runtime),
            "GH_TOKEN": "inherited-unrelated-token",
        })
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.addCleanup(self.directory.cleanup)

    def args(self, action, command=None):
        return SimpleNamespace(action=action, command=command or ["--", "fake-command"],
                               sops_program="fake-sops", secrets_file="ciphertext.yaml")

    def test_missing_command_never_decrypts(self):
        with patch.object(credentials, "decrypt_section") as decrypt:
            with self.assertRaises(credentials.CredentialError):
                credentials.scoped_command(self.args("github", ["--"]))
            decrypt.assert_not_called()

    def test_github_environment_is_scoped(self):
        def command(argv, env):
            self.assertEqual(argv, ["fake-command"])
            for name in ("GH_TOKEN", "GITHUB_TOKEN", "GITHUB_PAT_TOKEN"):
                self.assertEqual(env[name], FAKE)
            self.assertNotIn(FAKE, argv)
            return 7
        with patch.object(credentials, "decrypt_section", return_value={"pat": FAKE}), \
             patch.object(credentials, "run_command", side_effect=command):
            self.assertEqual(credentials.scoped_command(self.args("github")), 7)
        self.assertEqual(os.environ["GH_TOKEN"], "inherited-unrelated-token")

    def test_unsafe_runtime_directories_rejected(self):
        self.runtime.chmod(0o755)
        with self.assertRaises(credentials.CredentialError):
            credentials.runtime_root()
        self.runtime.chmod(0o700)
        (self.runtime / "nixos-credentials").symlink_to(self.runtime, target_is_directory=True)
        with self.assertRaises(credentials.CredentialError):
            credentials.runtime_root()

    def test_smb_staging_stable_private_and_removable(self):
        section = {"mac-mini": {"username": "fake-user", "obscured_password": FAKE}}
        with patch.object(credentials, "decrypt_section", return_value=section):
            self.assertEqual(credentials.smb_credential(self.args("unlock-smb")), 0)
        path = self.runtime / "nixos-credentials/mac-mini-smb.json"
        self.assertEqual(json.loads(path.read_text()), section["mac-mini"])
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(path.parent.stat().st_mode), 0o700)
        self.assertEqual(credentials.smb_credential(self.args("lock-smb")), 0)
        self.assertFalse(path.exists())

    def test_bad_smb_input_preserves_existing_staging(self):
        root = credentials.runtime_root()
        path = root / "mac-mini-smb.json"
        path.write_text("previous-staging")
        with patch.object(credentials, "decrypt_section", return_value={"mac-mini": {}}):
            with self.assertRaises(credentials.CredentialError):
                credentials.smb_credential(self.args("unlock-smb"))
        self.assertEqual(path.read_text(), "previous-staging")
        self.assertEqual(list(root.iterdir()), [path])

    def test_decryption_uses_object_selector_and_captures_diagnostics(self):
        result = SimpleNamespace(returncode=0, stdout=b'{"pat":"fake"}')
        with patch.object(subprocess, "run", return_value=result) as run:
            self.assertEqual(credentials.decrypt_section("sops", "encrypted.yaml", "github"), {"pat": "fake"})
        argv = run.call_args.args[0]
        self.assertEqual(argv, ["sops", "--decrypt", "--extract", '["github"]',
                                "--output-type", "json", "encrypted.yaml"])
        self.assertNotIn("GH_TOKEN", run.call_args.kwargs["env"])
        self.assertIs(run.call_args.kwargs["stdout"], subprocess.PIPE)
        self.assertIs(run.call_args.kwargs["stderr"], subprocess.PIPE)

    def test_decrypt_failures_never_echo_values(self):
        for result in (
            SimpleNamespace(returncode=1, stdout=FAKE.encode(), stderr=FAKE.encode()),
            SimpleNamespace(returncode=0, stdout=FAKE.encode()),
            SimpleNamespace(returncode=0, stdout=b'"scalar-not-object"'),
        ):
            with self.subTest(result=result), patch.object(subprocess, "run", return_value=result):
                output, errors = io.StringIO(), io.StringIO()
                with contextlib.redirect_stdout(output), contextlib.redirect_stderr(errors):
                    code = credentials.main(["--secrets-file", "encrypted.yaml", "github", "--", "true"])
                self.assertEqual(code, 1)
                self.assertEqual(output.getvalue(), "")
                self.assertNotIn(FAKE, errors.getvalue())

    def test_invalid_string_fields(self):
        for value in (None, "", "secret\nvalue", "secret\x00value", 123):
            with self.assertRaises(credentials.CredentialError):
                credentials.required_string({"pat": value}, "pat")

    def test_child_exit_status_and_signal_handler_restoration(self):
        before = {s: signal.getsignal(s) for s in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP)}
        self.assertEqual(credentials.run_command([sys.executable, "-c", "raise SystemExit(9)"],
                                                  credentials.clean_environment()), 9)
        for signum, handler in before.items():
            self.assertEqual(signal.getsignal(signum), handler)


if __name__ == "__main__":
    unittest.main()
