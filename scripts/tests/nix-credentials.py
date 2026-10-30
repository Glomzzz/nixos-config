"""Isolated credential-wrapper/config migration tests using fake tokens only."""

import os
from pathlib import Path
import runpy
import shutil
import subprocess
import sys
import tempfile
import unittest


WRAPPER, SCRUBBER = map(Path, sys.argv[1:3])
del sys.argv[1:3]


class CredentialsTest(unittest.TestCase):
    def test_config_migration_preserves_other_settings(self):
        scrub = runpy.run_path(str(SCRUBBER))["scrub"]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "nix.conf"
            path.write_text(
                "# harmless comment\nsubstituters = https://cache.nixos.org\n"
                "access-tokens = github.com=fake-test-token \\\n"
                "  other.example=fake-other-token\n"
                "extra-access-tokens = example.org=fake-extra-token\n"
                "experimental-features = nix-command flakes\n"
            )
            scrub(path)
            expected = (
                "# harmless comment\nsubstituters = https://cache.nixos.org\n"
                "experimental-features = nix-command flakes\n"
            )
            self.assertEqual(path.read_text(), expected)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            scrub(path)
            self.assertEqual(path.read_text(), expected)
            self.assertEqual([p.name for p in path.parent.iterdir()], ["nix.conf"])

    def test_read_token_precedes_general_gh_account(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            token = root / "read-token"
            token.write_text("fake-read-token\n")
            token.chmod(0o600)
            gh = root / "gh"
            gh.write_text(f"#!{shutil.which('bash')}\nprintf 'fake-gh-token\\n'\n")
            gh.chmod(0o755)
            env = dict(os.environ, HOME=str(root), XDG_CONFIG_HOME=str(root / "config"),
                       PATH=str(root) + os.pathsep + os.environ["PATH"],
                       NIX_GITHUB_TOKEN_FILE=str(token), NIX_CONFIG="max-jobs = 2")
            child = [sys.executable, "-c", (
                "import os; assert os.environ['NIX_CONFIG'] == "
                "'max-jobs = 2\\naccess-tokens = github.com=fake-read-token'"
            )]
            subprocess.run([shutil.which("bash"), str(WRAPPER), *child], env=env, check=True)
            token.chmod(0o644)
            result = subprocess.run([shutil.which("bash"), str(WRAPPER), "true"], env=env, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn(b"fake-read-token", result.stdout + result.stderr)
            env.pop("NIX_GITHUB_TOKEN_FILE")
            child[-1] = (
                "import os; assert os.environ['NIX_CONFIG'].endswith("
                "'access-tokens = github.com=fake-gh-token')"
            )
            subprocess.run([shutil.which("bash"), str(WRAPPER), *child], env=env, check=True)


if __name__ == "__main__":
    unittest.main()
