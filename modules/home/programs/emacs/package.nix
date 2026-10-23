{pkgs, ...}: {
  programs.emacs = {
    enable = true;
    # Keep Emacs on the newest pretest (31.x): nixpkgs' emacs31-pgtk tracks
    # upstream pretest releases on each flake update.
    package = pkgs.emacs31-pgtk.overrideAttrs (old: {
      patches = (old.patches or []) ++ [../../../../patches/emacs-cairo-interactive-image-filter.patch];
      # Emacs's C-level redisplay, image scaling, and GTK glue dominate
      # responsiveness; give them native codegen.
      NIX_CFLAGS_COMPILE = "-O2 -march=native";
    });
    # Lisp packages are managed by Emacs config, except mu4e (see ../mail),
    # which must be supplied by Nix to match the mu executable.
  };
}
