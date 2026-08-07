{pkgs, ...}: {
  # auto mount usb drives
  services.udiskie = {
    enable = true;
    package = pkgs.udiskie.overridePythonAttrs (oldAttrs: {
      disabledTestPaths =
        (oldAttrs.disabledTestPaths or [])
        ++ ["test/test_keyutils.py::TestKeyutils::test_invalidate"];
    });
  };
}
