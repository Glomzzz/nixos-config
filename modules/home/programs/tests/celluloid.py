"""Offline desktop integration and real libmpv configuration checks."""

import configparser
import ctypes
import json
import os
from pathlib import Path
import sys
from urllib.parse import unquote, urlparse
import xml.etree.ElementTree as ET

settings = json.loads(Path(sys.argv[1]).read_text())
package = Path(settings["package"])
preferences = settings["preferences"]
config_file = Path(settings["configFile"])

# Check the actual desktop ID and every declared audio/video default.
desktop_id = "io.github.celluloid_player.Celluloid.desktop"
desktop = configparser.ConfigParser(interpolation=None)
desktop.read(package / "share/applications" / desktop_id)
entry = desktop["Desktop Entry"]
assert entry["Exec"] == "celluloid %U"
assert entry.getboolean("DBusActivatable")
assert os.access(package / "bin/celluloid", os.X_OK)
assert {"video/mp4", "video/x-matroska", "audio/mpeg", "audio/flac"} <= settings["associations"].keys()
for mime, applications in settings["associations"].items():
    assert applications == [desktop_id], (mime, applications)
    assert mime in entry["MimeType"].split(";"), mime

# Validate keys and types against the schema shipped with this exact Celluloid.
schemas = list((package / "share/gsettings-schemas").glob("*/glib-2.0/schemas/*.gschema.xml"))
assert len(schemas) == 1, schemas
schema = ET.parse(schemas[0]).find("./schema[@id='io.github.celluloid-player.Celluloid']")
assert schema is not None
assert schema.get("path") == "/io/github/celluloid-player/celluloid/"
keys = {key.get("name"): key.get("type") for key in schema.findall("key")}
for key, value in preferences.items():
    assert keys[key] == ("b" if isinstance(value, bool) else "s"), (key, value)
assert preferences["mpv-config-enable"] is True
assert preferences["mpris-enable"] is True
uri = urlparse(preferences["mpv-config-file"])
assert uri.scheme == "file" and not uri.netloc
assert Path(unquote(uri.path)) == config_file

options = dict(line.split("=", 1) for line in config_file.read_text().splitlines() if line.strip())
assert options == {"hwdec": "auto-safe", "profile": "high-quality", "keep-open": "yes"}

# Use the same libmpv backend as Celluloid, not a second installed mpv player.
# Null outputs keep this test independent of displays, GPUs, and audio devices.
mpv = ctypes.CDLL(settings["libmpv"])
mpv.mpv_create.restype = ctypes.c_void_p
mpv.mpv_load_config_file.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
mpv.mpv_load_config_file.restype = ctypes.c_int
mpv.mpv_set_option_string.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
mpv.mpv_set_option_string.restype = ctypes.c_int
mpv.mpv_initialize.argtypes = [ctypes.c_void_p]
mpv.mpv_initialize.restype = ctypes.c_int
mpv.mpv_get_property_string.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
mpv.mpv_get_property_string.restype = ctypes.c_void_p
mpv.mpv_free.argtypes = [ctypes.c_void_p]
mpv.mpv_terminate_destroy.argtypes = [ctypes.c_void_p]
handle = mpv.mpv_create()
assert handle
try:
    assert mpv.mpv_load_config_file(handle, os.fsencode(config_file)) == 0
    for key, value in ((b"config", b"no"), (b"vo", b"null"), (b"ao", b"null")):
        assert mpv.mpv_set_option_string(handle, key, value) == 0
    assert mpv.mpv_initialize(handle) == 0
    for key, expected in ((b"hwdec", "auto-safe"), (b"keep-open", "yes"), (b"scale", "ewa_lanczossharp")):
        pointer = mpv.mpv_get_property_string(handle, b"options/" + key)
        assert pointer, key
        try:
            assert ctypes.string_at(pointer).decode() == expected, key
        finally:
            mpv.mpv_free(pointer)
finally:
    mpv.mpv_terminate_destroy(handle)

print("Celluloid desktop/MIME, GSettings, and libmpv configuration checks passed")
