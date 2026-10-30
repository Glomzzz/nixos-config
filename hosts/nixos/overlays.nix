_: {
  nixpkgs.overlays = [
    (import ../../pkgs)
    (_: prev: {
      # Local footprint policy, not a build workaround: Howdy needs ordinary
      # OpenCV, not every contrib module. Keep this scoped to Howdy and remove
      # it if nixpkgs adopts opencv4 here. Upstream supplies the thread limit.
      howdy = prev.howdy.overrideAttrs (oldAttrs: {
        passthru =
          oldAttrs.passthru
          // {
            pythonDeps = map (dep:
              if dep == "opencv4Full"
              then "opencv4"
              else dep)
            oldAttrs.passthru.pythonDeps;
          };
      });
    })
  ];

  nixpkgs.config.allowUnfree = true;
}
