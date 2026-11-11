{pkgs}:
pkgs.yubikey-touch-detector.overrideAttrs (old: {
  patches = (old.patches or []) ++ [./requester.patch];
  postPatch =
    (old.postPatch or "")
    + ''
      cp ${./requester_linux.go} notifier/requester_linux.go
    '';
  doCheck = false;
})
