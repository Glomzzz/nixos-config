{
  pkgs,
  hostPkgs,
}: let
  python = hostPkgs.howdy.pythonEnv;
  deps = hostPkgs.howdy.pythonDeps;
in
  assert hostPkgs.openldap.drvPath == pkgs.openldap.drvPath;
  assert hostPkgs.python3.drvPath == pkgs.python3.drvPath;
  assert hostPkgs.python3Packages.dlib.drvPath == pkgs.python3Packages.dlib.drvPath;
  assert hostPkgs.python3Packages.cli-helpers.drvPath == pkgs.python3Packages.cli-helpers.drvPath;
  assert hostPkgs.python3Packages.face-recognition.drvPath == pkgs.python3Packages.face-recognition.drvPath;
  assert builtins.elem "opencv4" deps && !(builtins.elem "opencv4Full" deps);
    pkgs.runCommand "scoped-overlays-check" {} ''
      export HOME="$TMPDIR/home"
      mkdir -p "$HOME"
      ${python}/bin/python - <<'PY'
      import os
      import cv2
      import dlib
      import face_recognition
      assert os.environ["OMP_NUM_THREADS"] == "1"
      print("Howdy imports upstream dlib/face-recognition and ordinary OpenCV with its thread limit")
      PY
      touch "$out"
    ''
