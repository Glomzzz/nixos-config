{
  config,
  pkgs,
}: let
  settings = pkgs.writeText "login-settings.json" (builtins.toJSON {
    greetd = config.services.greetd.settings;
    inherit (config.services.displayManager) autoLogin;
    regreet = config.services.displayManager.regreet.settings;
    loginPam = config.security.pam.services.login.text;
    greetdPam = config.security.pam.services.greetd.text;
    fishLogin = config.programs.fish.loginShellInit;
    autologinUser = config.services.getty.autologinUser;
    gettyConflict = config.systemd.services.greetd.unitConfig.Conflicts;
    sessions = config.services.displayManager.sessionData.sessionNames;
    greeterConfig = toString config.environment.etc."greetd/niri.kdl".source;
  });
in
  pkgs.runCommand "login-check"
  {
    nativeBuildInputs = [pkgs.python3 config.programs.niri.package];
    greeterConfig = config.environment.etc."greetd/niri.kdl".source;
    desktops = config.services.displayManager.sessionData.desktops;
  }
  ''
    niri validate --config "$greeterConfig"
    test -f "$desktops/share/wayland-sessions/niri.desktop"
    grep -q '^Exec=niri-session$' "$desktops/share/wayland-sessions/niri.desktop"
    python3 - ${settings} <<'PY'
    import json
    import pathlib
    import sys

    with open(sys.argv[1]) as source:
        settings = json.load(source)
    greetd = settings["greetd"]
    assert greetd["terminal"]["vt"] == 1
    assert greetd["default_session"]["user"] == "greeter"
    command = greetd["default_session"]["command"]
    assert "dbus-run-session" in command and "/bin/niri --config " in command
    assert "--session" not in command and "niri-session" not in command
    assert "initial_session" not in greetd, "greetd must not bypass authentication"
    assert not settings["autoLogin"]["enable"] and settings["autologinUser"] is None
    assert "getty@tty1.service" in settings["gettyConflict"]
    assert "niri" in settings["sessions"]
    assert "NIRI_SESSION_LAUNCHED" not in settings["fishLogin"]

    login = settings["loginPam"]
    assert "pam_howdy.so" not in login, "initial login must stay password based"
    unix_auth = [line for line in login.splitlines() if line.startswith("auth ") and "pam_unix.so" in line]
    assert unix_auth and all("nullok" not in line for line in unix_auth)
    assert "pam_gnome_keyring.so" in login and "auto_start" in login
    assert "auth substack login" in settings["greetdPam"]
    assert "session include login" in settings["greetdPam"]

    regreet = settings["regreet"]
    assert pathlib.Path(regreet["background"]["path"]).is_file()
    assert regreet["background"]["fit"] == "Cover"
    assert regreet["GTK"]["application_prefer_dark_theme"]
    assert regreet["widget"]["clock"]["format"]
    greeter = pathlib.Path(settings["greeterConfig"]).read_text()
    assert 'options "ctrl:nocaps"' in greeter
    assert 'output "eDP-1"' in greeter and "scale 1.5" in greeter
    print("Graphical login, password/keyring PAM, and session discovery passed")
    PY
    touch "$out"
  ''
