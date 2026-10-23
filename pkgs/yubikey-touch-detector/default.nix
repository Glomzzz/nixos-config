{pkgs}:
pkgs.yubikey-touch-detector.overrideAttrs (old: {
  patches = (old.patches or []) ++ [./requester.patch];
  postPatch =
    (old.postPatch or "")
    + ''
      cp ${./requester_linux.go} notifier/requester_linux.go
      cp ${./requester_linux_test.go} notifier/requester_linux_test.go
    '';
  nativeBuildInputs = (old.nativeBuildInputs or []) ++ [pkgs.dbus];
  # Never connect tests to the desktop bus or the real agent sockets.
  # Run upstream's proxy/protocol tests and our attribution/notification tests.
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    YUBIKEY_TOUCH_TEST_PRIVATE_BUS=1 dbus-run-session \
      --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- go test -race ./...
    runHook postCheck
  '';
})
