"""Saved-PIN tests: fake secrets/devices/backend only; no GPG or hardware access."""

import argparse
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


PINENTRY_PATH, PROVISION_PATH = sys.argv[1:3]
del sys.argv[1:3]
pinentry = load("saved_pinentry", PINENTRY_PATH)
provision = load("saved_pin_provision", PROVISION_PATH)
FAKE_PIN = b"fake%pin with spaces"
SERIAL = "12345678"


def description(counter=7, serial="12 345 678"):
    result = f"Please unlock the card\n\n\x1eNumber\x1f: {serial}\nHolder\x1f: Test User".encode()
    return result if counter is None else result + f"\nCounter\x1f: {counter}".encode()


def escape(value):
    return value.replace(b"%", b"%25").replace(b"\n", b"%0A")


class SavedPinTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.pin = self.root / "pin"
        self.pin.write_bytes(FAKE_PIN)
        self.pin.chmod(0o400)
        self.runtime = self.root / "runtime"
        self.runtime.mkdir(mode=0o700)
        self.usb = self.root / "usb"
        self.device = self.usb / "1-1"
        self.device.mkdir(parents=True)
        for name, value in {"idVendor": "1050", "busnum": "1", "devnum": "2"}.items():
            (self.device / name).write_text(value)
        self.args = argparse.Namespace(pin_file=str(self.pin), card_serial=SERIAL,
                                      runtime_dir=str(self.runtime), usb_root=str(self.usb))

    def request(self, counter=7):
        request = pinentry.Request()
        request.observe(b"SETDESC", escape(description(counter)))
        request.observe(b"SETPROMPT", b"PIN")
        request.observe(b"SETKEYINFO", b"--clear")
        return request

    def test_auto_once_and_signature_counter_proves_progress(self):
        request = self.request()
        self.assertEqual(request.saved_pin(self.args), FAKE_PIN)
        self.assertIsNone(request.saved_pin(self.args))
        self.assertIsNone(self.request().saved_pin(self.args))
        self.assertEqual(self.request(counter=8).saved_pin(self.args), FAKE_PIN)

    def test_qt_without_tabbing_uses_plain_layout(self):
        request = self.request()
        plain = description().replace(b"\x1e", b"").replace(b"\x1f", b"")
        request.observe(b"SETDESC", escape(plain))
        self.assertEqual(request.saved_pin(self.args), FAKE_PIN)

    def test_new_usb_connection_rearms(self):
        self.assertEqual(self.request().saved_pin(self.args), FAKE_PIN)
        (self.device / "devnum").write_text("3")
        self.assertEqual(self.request().saved_pin(self.args), FAKE_PIN)

    def test_no_counter_does_not_replay(self):
        self.assertEqual(self.request(counter=None).saved_pin(self.args), FAKE_PIN)
        self.assertIsNone(self.request(counter=None).saved_pin(self.args))
        self.assertIsNone(self.request(counter=7).saved_pin(self.args))

    def test_no_auto_across_sign_and_auth_without_progress(self):
        self.assertEqual(self.request().saved_pin(self.args), FAKE_PIN)
        self.assertIsNone(self.request(counter=None).saved_pin(self.args))

    def test_wrong_serial_software_admin_new_pin_and_low_tries_are_manual(self):
        for value in [description(serial="87 654 321"), b"Software key passphrase",
                      description().replace(b"Please unlock the card", b"Please enter the Admin PIN"),
                      description().replace(b"Please unlock the card", b"New PIN"),
                      description() + b"\n\nRemaining attempts: 2"]:
            with self.subTest(description=value):
                request = self.request()
                request.observe(b"SETDESC", escape(value))
                self.assertIsNone(request.saved_pin(self.args))

    def test_prompt_error_repeat_quality_and_user_data_are_manual(self):
        for command, value in [(b"SETPROMPT", b"Admin PIN"), (b"SETKEYINFO", b"n/FAKE"),
                               (b"SETERROR", b"Bad PIN"), (b"SETREPEAT", b"Repeat"),
                               (b"SETQUALITYBAR", b""), (b"SETGENPIN", b"Suggest"),
                               (b"OPTION", b"pinentry-user-data=manual")]:
            with self.subTest(command=command):
                request = self.request()
                request.observe(command, value)
                self.assertIsNone(request.saved_pin(self.args))

    def test_reset_discards_prompt_and_does_not_remove_replay_guard(self):
        request = self.request()
        self.assertEqual(request.saved_pin(self.args), FAKE_PIN)
        request.observe(b"RESET", b"")
        self.assertIsNone(request.saved_pin(self.args))
        self.assertIsNone(self.request().saved_pin(self.args))

    def test_key_description_prefix_is_supported(self):
        request = self.request()
        request.observe(b"SETDESC", escape(b"Signing key details\n\n" + description()))
        self.assertEqual(request.saved_pin(self.args), FAKE_PIN)

    def test_invalid_pins_and_missing_secret_are_manual(self):
        for value in [b"short", b"fakepin\n", b"fake\x00pin", b"fake\x7fpin", b"\xff" * 8, b"x" * 128]:
            with self.subTest(value=value):
                self.pin.chmod(0o600)
                self.pin.write_bytes(value)
                self.pin.chmod(0o400)
                self.assertIsNone(self.request().saved_pin(self.args))
        self.pin.unlink()
        self.assertIsNone(self.request().saved_pin(self.args))

    def test_secret_permissions_and_symlinks_are_rejected(self):
        self.pin.chmod(0o644)
        self.assertIsNone(self.request().saved_pin(self.args))
        self.pin.chmod(0o400)
        actual = self.root / "actual"
        self.pin.rename(actual)
        self.pin.symlink_to(actual)
        self.assertIsNone(self.request().saved_pin(self.args))

    def test_unsafe_runtime_missing_device_and_multiple_devices_are_manual(self):
        self.runtime.chmod(0o755)
        self.assertIsNone(self.request().saved_pin(self.args))
        self.runtime.chmod(0o700)
        (self.device / "idVendor").write_text("0000")
        self.assertIsNone(self.request().saved_pin(self.args))
        (self.device / "idVendor").write_text("1050")
        second = self.usb / "1-2"
        second.mkdir()
        for name, value in {"idVendor": "1050", "busnum": "1", "devnum": "3"}.items():
            (second / name).write_text(value)
        self.assertIsNone(self.request().saved_pin(self.args))

    def test_unsafe_or_corrupt_state_is_manual(self):
        state = self.runtime / "yubikey-pin"
        state.mkdir(mode=0o700)
        attempt = state / "attempt.json"
        attempt.write_text("not json")
        attempt.chmod(0o600)
        self.assertIsNone(self.request().saved_pin(self.args))
        attempt.unlink()
        attempt.symlink_to(self.pin)
        self.assertIsNone(self.request().saved_pin(self.args))

    def test_claim_state_contains_no_pin_or_hash(self):
        self.assertEqual(self.request().saved_pin(self.args), FAKE_PIN)
        state = self.runtime / "yubikey-pin/attempt.json"
        data = state.read_bytes()
        self.assertNotIn(FAKE_PIN, data)
        self.assertEqual(set(json.loads(data)), {"serial", "device", "secret_version", "counter"})
        self.assertEqual(state.stat().st_mode & 0o777, 0o600)

    def run_protocol(self, commands):
        backend = self.root / "fake-pinentry"
        backend.write_text(f"#!{sys.executable}\n" + '''import sys
print("OK fake backend", flush=True)
for line in sys.stdin.buffer:
    command = line.split(maxsplit=1)[0].upper()
    if command == b"GETPIN":
        print("D manual-fake", flush=True)
    if command == b"INQUIRYTEST":
        print("INQUIRE QUALITY fake", flush=True)
        for reply in sys.stdin.buffer:
            if reply.strip() in (b"END", b"CAN"):
                break
    print("OK", flush=True)
    if command == b"BYE":
        break
''')
        backend.chmod(0o700)
        return subprocess.run(
            [sys.executable, PINENTRY_PATH, "--fallback", str(backend),
             "--card-serial", SERIAL, "--pin-file", str(self.pin),
             "--runtime-dir", str(self.runtime), "--usb-root", str(self.usb)],
            input=commands, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10,
        )

    def test_protocol_auto_percent_escaping_and_manual_retry(self):
        commands = (b"SETKEYINFO --clear\nSETDESC " + escape(description()) +
                    b"\nSETPROMPT PIN\nGETPIN\nSETERROR Bad PIN\nGETPIN\nBYE\n")
        result = self.run_protocol(commands)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(b"D " + escape(FAKE_PIN) + b"\nOK\n", result.stdout)
        self.assertEqual(result.stdout.count(b"D " + escape(FAKE_PIN)), 1)
        self.assertIn(b"D manual-fake", result.stdout)
        self.assertEqual(result.stderr, b"")

    def test_protocol_returns_provider_pid(self):
        result = self.run_protocol(b"GETINFO pid\nBYE\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        data, = [line for line in result.stdout.splitlines() if line.startswith(b"D ")]
        self.assertTrue(data[2:].isdigit())
        self.assertGreater(int(data[2:]), 0)

    def test_fallback_inquiry_and_normal_software_prompt(self):
        result = self.run_protocol(b"SETDESC Software key\nSETPROMPT Passphrase:\nINQUIRYTEST\nD 100\nEND\nGETPIN\nBYE\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(b"INQUIRE QUALITY fake", result.stdout)
        self.assertIn(b"D manual-fake", result.stdout)
        self.assertNotIn(escape(FAKE_PIN), result.stdout)

    def test_protocol_missing_secret_uses_manual_backend(self):
        self.pin.unlink()
        result = self.run_protocol(b"SETKEYINFO --clear\nSETDESC " + escape(description()) + b"\nSETPROMPT PIN\nGETPIN\nBYE\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(b"D manual-fake", result.stdout)

    def test_line_length_is_bounded(self):
        with self.assertRaises(ValueError):
            pinentry.read_line(io.BytesIO(b"X" * 5000 + b"\n"))


class ProvisionTests(unittest.TestCase):
    def test_pin_only_in_sops_stdin_never_argv(self):
        def run(argv, **kwargs):
            self.assertNotIn(FAKE_PIN.decode(), " ".join(argv))
            self.assertEqual(json.loads(kwargs["input"]), {"openpgp_user_pin": FAKE_PIN.decode()})
            self.assertEqual(argv, ["fake-sops", "--encrypt", "--filename-override",
                                   "secrets/hosts/test-yubikey-pin.yaml", "--input-type", "json",
                                   "--output-type", "yaml", "/dev/stdin"])
            return subprocess.CompletedProcess(argv, 0, b"openpgp_user_pin: ENC[AES256_GCM,fake]\n", b"")
        with patch.object(provision.subprocess, "run", side_effect=run):
            ciphertext = provision.encrypt_pin("fake-sops", "secrets/hosts/test-yubikey-pin.yaml", FAKE_PIN.decode(), "/fake")
        self.assertNotIn(FAKE_PIN, ciphertext)

    def test_sops_error_details_do_not_escape(self):
        with patch.object(provision.subprocess, "run", return_value=subprocess.CompletedProcess([], 1, FAKE_PIN, FAKE_PIN)):
            with self.assertRaises(ValueError) as caught:
                provision.encrypt_pin("fake-sops", "target.yaml", FAKE_PIN.decode(), "/fake")
        self.assertNotIn(FAKE_PIN.decode(), str(caught.exception))

    def test_non_tty_input_is_refused_without_prompt(self):
        with patch.object(provision.sys.stdin, "isatty", return_value=False), \
             patch.object(provision.getpass, "getpass") as prompt, \
             patch("sys.stderr", new_callable=io.StringIO):
            self.assertEqual(provision.main(["--sops-program", "fake", "--hostname", "test"]), 1)
        prompt.assert_not_called()

    def test_ciphertext_atomic_no_clobber_and_explicit_replace(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "secret.yaml"
            provision.save_ciphertext(target, b"ciphertext")
            self.assertEqual(target.read_bytes(), b"ciphertext")
            self.assertEqual(target.stat().st_mode & 0o777, 0o600)
            with self.assertRaises(ValueError):
                provision.save_ciphertext(target, b"replacement")
            provision.save_ciphertext(target, b"replacement", replace=True)
            self.assertEqual(target.read_bytes(), b"replacement")
            self.assertEqual([path.name for path in Path(directory).iterdir()], ["secret.yaml"])

    def test_symlink_target_is_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "secret.yaml"
            target.symlink_to(Path(directory) / "missing")
            with self.assertRaises(ValueError):
                provision.save_ciphertext(target, b"ciphertext", replace=True)


if __name__ == "__main__":
    unittest.main()
