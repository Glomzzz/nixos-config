"""Offline launcher regressions; never start Steam, a game, or a compositor."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ENV_KEYS = (
    "DISPLAY",
    "WAYLAND_DISPLAY",
    "SDL_IM_MODULE",
    "XMODIFIERS",
    "SDL_VIDEODRIVER",
    "SDL_VIDEO_DRIVER",
    "VK_DRIVER_FILES",
)

if sys.argv[1].startswith("--capture-"):
    print(json.dumps({
        "runner": sys.argv[1].removeprefix("--capture-"),
        "args": sys.argv[2:],
        "env": {key: os.environ.get(key) for key in ENV_KEYS},
    }))
    sys.exit(0)

LAUNCHER = sys.argv.pop(1)


class LauncherTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.data = self.home / "data with spaces"
        self.env = os.environ.copy()
        self.env.update({
            "HOME": str(self.home),
            "XDG_DATA_HOME": str(self.data),
            "DISPLAY": ":42",
            "WAYLAND_DISPLAY": "wayland-test",
            "SDL_IM_MODULE": "ibus",
            "XMODIFIERS": "@im=ibus",
            "SDL_VIDEODRIVER": "wayland",
            "SDL_VIDEO_DRIVER": "wayland",
        })
        for key in ("SteamAppId", "STEAM_COMPAT_APP_ID", "VK_DRIVER_FILES"):
            self.env.pop(key, None)
        self.game = self.home / "fake game"
        self.game.write_text(
            f"#!{sys.executable}\n"
            "import os, sys\n"
            f"os.execv(sys.executable, [sys.executable, {__file__!r}, "
            "'--capture-game', *sys.argv[1:]])\n"
        )
        self.game.chmod(0o755)

    def launch(self, app_id=None, *, extra_env=None):
        env = self.env.copy()
        if app_id is not None:
            env["SteamAppId"] = str(app_id)
        env.update(extra_env or {})
        args = [str(self.game), "-novid", "argument with spaces", "literal;$(false)"]
        result = subprocess.run(
            [LAUNCHER, *args], env=env, check=True, capture_output=True, text=True,
        )
        return json.loads(result.stdout), args

    def video(self, user="123"):
        path = self.data / "Steam/userdata" / user / "570/local/cfg/video.txt"
        path.parent.mkdir(parents=True)
        path.write_text(
            '"VideoConfig"\n{\n'
            '\t"setting.defaultres"\t"1707"\n'
            '\t"setting.defaultresheight"\t"1067"\n'
            '\t"setting.fullscreen"\t"0"\n'
            '\t"setting.nowindowborder"\t"1"\n'
            '\t"unrelated"\t"keep me"\n}\n'
        )
        return path

    def assert_dota(self, result, args):
        self.assertEqual(result["runner"], "game")
        self.assertEqual(result["args"], args[1:] + ["-w", "2560", "-h", "1600", "-fullscreen"])
        self.assertEqual(result["env"]["SDL_IM_MODULE"], "fcitx")
        self.assertEqual(result["env"]["XMODIFIERS"], "@im=fcitx")
        self.assertEqual(result["env"]["SDL_VIDEODRIVER"], "x11")
        self.assertEqual(result["env"]["SDL_VIDEO_DRIVER"], "x11")
        self.assertEqual(result["env"]["DISPLAY"], ":42")
        self.assertEqual(result["env"]["WAYLAND_DISPLAY"], "wayland-test")

    def test_dota_direct_and_saved_native_mode(self):
        videos = [self.video(), self.video("456")]
        result, args = self.launch(570)
        self.assert_dota(result, args)
        for path in videos:
            text = path.read_text()
            for key, value in (
                ("defaultres", "2560"), ("defaultresheight", "1600"),
                ("fullscreen", "1"), ("nowindowborder", "0"),
            ):
                self.assertIn(f'"setting.{key}"\t"{value}"', text)
            self.assertIn('"unrelated"\t"keep me"', text)
            self.assertEqual(list(path.parent.glob(".video.txt.*")), [])

    def test_dota_first_launch_and_compat_app_id(self):
        result, args = self.launch(extra_env={"STEAM_COMPAT_APP_ID": "570"})
        self.assert_dota(result, args)
        self.assertFalse((self.data / "Steam/userdata").exists())

    def test_other_games_keep_gamescope_and_input_environment(self):
        for app_id in (None, 999999, 379430, 1862520, 728880, 4001890, 105600):
            with self.subTest(app_id=app_id):
                result, args = self.launch(app_id)
                self.assertEqual(result["runner"], "gamescope")
                split = result["args"].index("--")
                options, game_args = result["args"][:split], result["args"][split + 1:]
                self.assertEqual(game_args[:len(args)], args)
                self.assertIn("--fullscreen", options)
                self.assertEqual(options[options.index("--backend") + 1], "wayland")
                self.assertEqual("--force-grab-cursor" in options, app_id != 379430)
                self.assertEqual(result["env"]["SDL_IM_MODULE"], "ibus")
                self.assertEqual(result["env"]["SDL_VIDEO_DRIVER"], "wayland")
                if app_id == 379430:
                    self.assertEqual(game_args[len(args):], ["-r_width", "2560", "-r_height", "1600", "-r_fullscreen", "1"])

    def test_steam_app_id_takes_precedence(self):
        result, _ = self.launch(379430, extra_env={"STEAM_COMPAT_APP_ID": "570"})
        self.assertEqual(result["runner"], "gamescope")

    def test_home_data_fallback(self):
        self.env.pop("XDG_DATA_HOME")
        self.data = self.home / ".local/share"
        video = self.video()
        result, args = self.launch(570)
        self.assert_dota(result, args)
        self.assertIn('"setting.defaultres"\t"2560"', video.read_text())

    def test_stale_icd_removed_but_valid_override_retained(self):
        result, _ = self.launch(570, extra_env={"VK_DRIVER_FILES": str(self.home / "missing.json")})
        self.assertIsNone(result["env"]["VK_DRIVER_FILES"])
        icd = self.home / "valid.json"
        icd.write_text("{}")
        result, _ = self.launch(570, extra_env={"VK_DRIVER_FILES": str(icd)})
        self.assertEqual(result["env"]["VK_DRIVER_FILES"], str(icd))


unittest.main()
