"""Offline contract tests for Waybar assets and shell helpers."""

import json
import os
from pathlib import Path
import subprocess
import shutil
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
SETTINGS = Path(sys.argv.pop(1)) if len(sys.argv) > 1 else None


def bash(script, *, env=None):
    return subprocess.run(
        ["bash", "-euo", "pipefail", "-c", script],
        env=env,
        text=True,
        capture_output=True,
        check=True,
    ).stdout


class WaybarTests(unittest.TestCase):
    def test_menu_actions_match_xml(self):
        menu = ET.parse(ROOT / "power-menu.xml")
        ids = [obj.get("id") for obj in menu.iter("object")]
        self.assertEqual(len(ids), len(set(ids)))
        actions = {
            obj.get("id")
            for obj in menu.iter("object")
            if obj.get("class") == "GtkMenuItem"
            and obj.find("./child[@type='submenu']") is None
        }
        if SETTINGS is None:
            self.skipTest("Pass evaluated Waybar settings JSON to check menu actions")
        settings = json.loads(SETTINGS.read_text())
        self.assertEqual(actions, set(settings["main"]["battery"]["menu-actions"]))

    def test_workspace_style_precedence(self):
        css = (ROOT / "style.css").read_text()
        self.assertLess(
            css.index("#workspaces button.empty {"),
            css.index("#workspaces button.focused {"),
        )
        self.assertIn("#workspaces button.active:not(.focused)", css)

    def weather(self, payload, status=0):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            # Mock HTTP only; the real jq validates and escapes output.
            curl = directory / "curl"
            curl.write_text(
                f'#!{shutil.which("bash")}\nprintf "%s" "$MOCK_RESPONSE"\n'
                'exit "$MOCK_STATUS"\n'
            )
            curl.chmod(0o755)
            env = os.environ | {
                "PATH": str(directory) + os.pathsep + os.environ["PATH"],
                "MOCK_RESPONSE": payload,
                "MOCK_STATUS": str(status),
            }
            output = bash(f'source "{ROOT / "scripts/weather.sh"}"', env=env)
            self.assertEqual(len(output.splitlines()), 1)
            return json.loads(output)

    def test_weather_success_and_unknown_code(self):
        for code, description in [(0, "Clear sky"), (123, "Unmapped WMO code 123")]:
            result = self.weather(json.dumps({"current": {
                "temperature_2m": 27.4,
                "weather_code": code,
                "time": "2026-10-08T00:00",
            }}))
            self.assertEqual(result["class"], "weather")
            self.assertIn("27°C", result["text"])
            self.assertIn(description, result["tooltip"])
            self.assertIn("\nUpdated 2026-10-08T00:00", result["tooltip"])

    def test_weather_failure_is_valid_json(self):
        cases = [
            ("", 1),
            ("", 0),
            ("not json", 0),
            ("{}", 0),
            (json.dumps({"current": {
                "temperature_2m": 27,
                "weather_code": 0,
                "time": "",
            }}), 0),
        ]
        for payload, status in cases:
            with self.subTest(payload=payload, status=status):
                self.assertEqual(self.weather(payload, status), {
                    "text": "", "tooltip": "weather unavailable", "class": "unavailable",
                })

    def test_netspeed_padding_and_colon_unescape(self):
        # Source function definitions only, never the polling loop or nmcli.
        definitions = (ROOT / "scripts/netspeed.sh").read_text().split(
            "TOOLTIP_EVERY=5", 1
        )[0]
        output = bash(definitions + r'''
for value in 0 9 99 99.96 1024 1048576 16777216 18446744073709551615; do
  IFS=$'\t' read -r number unit < <(scale "$value")
  label=$(pad "$number" "$unit")
  test "${#label}" -eq 7
  printf '%s\n' "$label"
done
unescape 'Cafe\:Free'
''')
        lines = output.splitlines()
        self.assertTrue(all(len(line) == 7 for line in lines[:-1]))
        self.assertEqual(lines[-1], "Cafe:Free")

    def test_netspeed_disconnected_tooltip(self):
        definitions = (ROOT / "scripts/netspeed.sh").read_text().split(
            "TOOLTIP_EVERY=5", 1
        )[0]
        self.assertEqual(bash(definitions + "\nprimary() { :; }\nconninfo\n"), "Disconnected")


if __name__ == "__main__":
    unittest.main()
