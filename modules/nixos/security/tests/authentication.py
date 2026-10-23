"""Validate generated auth policy and execute its control flow using Linux PAM.

Replace only camera/key/password modules with pam_debug or missing modules,
retaining generated control flags, ordering, and final pam_deny. No real hardware
or credentials are used, and the system PAM configuration is never changed.
"""

import itertools
import json
import pathlib
import subprocess
import sys
import tempfile

settings_path, pam_modules, runner = sys.argv[1:]
with open(settings_path) as source:
    settings = json.load(source)
pam = settings["pam"]
assert not settings["globalHowdy"], "Howdy must be opt-in, not system-wide"
assert not settings["globalU2f"], "U2F must be opt-in, not system-wide"
for service, text in pam.items():
    if service not in ("sudo", "swaylock"):
        for module in ("pam_howdy.so", "pam_u2f.so"):
            assert module not in text, f"{module} unexpectedly enabled for {service}"

assert "ignore-empty-password" not in settings["locker"].splitlines(), (
    "empty Enter must reach PAM to start face/key authentication"
)


def auth_rules(service):
    return [line.split("#", 1)[0].split() for line in pam[service].splitlines()
            if line.startswith("auth ")]


modules = {"pam_howdy.so": "face", "pam_u2f.so": "key", "pam_unix.so": "password"}
for service in ("sudo", "swaylock"):
    rules = auth_rules(service)
    assert len(rules) == 4, "review the truth-table test when adding authentication modules"
    assert [pathlib.Path(rule[2]).name for rule in rules] == [
        "pam_howdy.so", "pam_u2f.so", "pam_unix.so", "pam_deny.so",
    ], f"{service} must try face, key, password, then deny"
    assert all(rule[1] == "sufficient" for rule in rules[:3]), (
        f"{service} must accept any one of face/key/password"
    )
    assert rules[-1][1] == "required"
    assert "nullok" not in rules[2], "empty passwords must not authenticate"
    options = set(rules[1][3:])
    origin = f"pam://{settings['hostname']}"
    assert {"authfile=/etc/u2f-mappings", f"origin={origin}", f"appid={origin}",
            "cue", "userpresence=1", "pinverification=0", "userverification=0"} <= options
    assert not {"nouserok", "alwaysok"} & options, "missing enrollment must not authenticate"
    marker = f"/run/yubikey-touch/{settings['pcscUser']}/{service}"
    assert f"authpending_file={marker}" in options
    assert f"f {marker} 0444 root root -" in settings["tmpfiles"], (
        "PAM attribution markers must be precreated, empty, root-owned and read-only"
    )

    # Exercise both stacks: the full OR truth table plus absent/broken modules.
    # An unenrolled/missing key is a failure, never a successful authentication.
    with tempfile.TemporaryDirectory() as directory:
        for face, key, password in itertools.product(
                ("success", "auth_err", "missing"),
                ("success", "auth_err", "missing"),
                ("success", "auth_err")):
            name = f"{service}-face-{face}-key-{key}-password-{password}"
            results = {"face": face, "key": key, "password": password}
            stack = []
            for rule in rules:
                module = pathlib.Path(rule[2]).name
                if module not in modules:
                    stack.append(" ".join(rule))
                elif results[modules[module]] == "missing":
                    stack.append(f"auth {rule[1]} /missing/{module}")
                else:
                    result = results[modules[module]]
                    stack.append(f"auth {rule[1]} {pam_modules}/pam_debug.so auth={result}")
            pathlib.Path(directory, name).write_text("\n".join(stack) + "\n")
            result = subprocess.run([runner, directory, name], check=False)
            accepted = "success" in results.values()
            assert result.returncode == (0 if accepted else 1), (
                f"{name}: incorrect face OR key OR password authentication"
            )

print("Face/key/password OR truth tables, missing-device fallback, PAM scope, and locker input passed")
