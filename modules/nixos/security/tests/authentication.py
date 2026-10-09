"""Validate generated auth policy and execute its control flow using Linux PAM.

Replace only the camera/password modules with pam_debug, retaining the generated
control flags, ordering, and final pam_deny. No real credentials or camera access.
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
for service in ("login", "greetd", "sshd", "su", "polkit-1"):
    assert "pam_howdy.so" not in pam[service], f"camera unexpectedly required by {service}"

assert "ignore-empty-password" not in settings["locker"].splitlines(), (
    "empty Enter must reach PAM to start face authentication"
)


def auth_rules(service):
    # The expected local-account stack uses simple PAM control flags.
    return [line.split("#", 1)[0].split() for line in pam[service].splitlines()
            if line.startswith("auth ")]


for service in ("sudo", "swaylock"):
    rules = auth_rules(service)
    howdy = [rule for rule in rules if rule[2].endswith("/pam_howdy.so")]
    unix = [rule for rule in rules if rule[2].endswith("/pam_unix.so")]
    assert len(howdy) == len(unix) == 1, f"unexpected {service} authentication stack"
    assert howdy[0][1] == unix[0][1] == "sufficient", f"{service} must accept either factor"
    assert rules.index(howdy[0]) < rules.index(unix[0]), "face success must skip the password"
    assert "nullok" not in unix[0], "empty passwords must not authenticate"
    assert rules[-1][1] == "required" and rules[-1][2].endswith("/pam_deny.so")

# Test swaylock's actual generated control flow with safe synthetic results.
rules = auth_rules("swaylock")
assert len(rules) == 3, "review the truth-table test when adding authentication modules"
with tempfile.TemporaryDirectory() as directory:
    for face, password in itertools.product((False, True), repeat=2):
        service = f"face-{int(face)}-password-{int(password)}"
        stack = []
        for rule in rules:
            module = pathlib.Path(rule[2]).name
            if module in ("pam_howdy.so", "pam_unix.so"):
                success = face if module == "pam_howdy.so" else password
                result = "success" if success else "auth_err"
                stack.append(f"auth {rule[1]} {pam_modules}/pam_debug.so auth={result}")
            else:
                stack.append(" ".join(rule))
        pathlib.Path(directory, service).write_text("\n".join(stack) + "\n")
        result = subprocess.run([runner, directory, service], check=False)
        assert result.returncode == (0 if face or password else 1), (
            f"face={face}, password={password}: incorrect OR authentication"
        )

    # A missing camera module must still permit a successful password.
    pathlib.Path(directory, "missing-camera").write_text(
        f"auth {rules[0][1]} /missing/pam_howdy.so\n"
        f"auth {rules[1][1]} {pam_modules}/pam_debug.so auth=success\n"
        + " ".join(rules[2]) + "\n"
    )
    subprocess.run([runner, directory, "missing-camera"], check=True)

print("Howdy/password OR truth table, camera fallback, and locker input settings passed")
