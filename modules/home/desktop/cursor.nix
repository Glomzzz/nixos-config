{pkgs, ...}: {
  # KDE's Breeze cursor set. Upstream names the dark variant `breeze_cursors`
  # (the light one is `Breeze_Light`), so the directory name looks generic but
  # is in fact the dark theme Plasma ships as its default.
  #
  # This is the single source of truth for the pointer: niri reads the name and
  # size back out of `home.pointerCursor` in niri/settings.nix, so the
  # compositor cursor and the XCURSOR_* variables handed to Xwayland and to
  # every client cannot drift apart.
  home.pointerCursor = {
    # Home Manager still infers enablement from the attrset being set at all,
    # but warns about it; setting this explicitly keeps evaluation quiet.
    enable = true;
    package = pkgs.kdePackages.breeze;
    name = "breeze_cursors";
    # Breeze ships pre-rendered bitmaps at multiples of 6 up to 72; 24 is a
    # native size, so nothing is scaled.
    size = 24;
  };
}
