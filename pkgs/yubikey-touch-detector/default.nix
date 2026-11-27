{pkgs}:
pkgs.yubikey-touch-detector.overrideAttrs (old: {
  patches = (old.patches or []) ++ [./requester.patch];
  postPatch =
    (old.postPatch or "")
    + ''
      cp ${./requester_linux.go} notifier/requester_linux.go
      # Journal every touch prompt (requester names only) for later review.
      substituteInPlace notifier/libnotify.go \
        --replace-fail 'if err := showNotification(conn, &reference, &notification); err != nil {' \
        'log.Infof("YubiKey touch requested: %s", notification.Summary)
		if err := showNotification(conn, &reference, &notification); err != nil {'
    '';
  doCheck = false;
})
