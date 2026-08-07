{lib, ...}: {
  home.activation.refreshKdeApplicationCache = lib.hm.dag.entryAfter ["linkGeneration"] ''
    if command -v kbuildsycoca6 >/dev/null 2>&1; then
      run kbuildsycoca6 --noincremental
    fi
  '';
}
