_: {
  nixpkgs.overlays = [
    (import ../../pkgs)
    (final: prev: {
      python3 = prev.python3.override {
        packageOverrides = _: pySuper: {
          cli-helpers = pySuper.cli-helpers.overridePythonAttrs (_: {
            doCheck = false;
          });
          # dlib 20.0.1 moved this function, so nixpkgs' build-cores.patch no
          # longer applies. Preserve the patch's intent until nixpkgs fixes it.
          dlib = pySuper.dlib.overridePythonAttrs (oldAttrs: {
            patches = [];
            preConfigure = "";
            preBuild =
              (oldAttrs.preBuild or "")
              + ''
                export CMAKE_BUILD_PARALLEL_LEVEL="$NIX_BUILD_CORES"
              '';
          });
          face-recognition = pySuper.face-recognition.overrideAttrs (_: {
            doInstallCheck = false;
          });
        };
      };
      python3Packages = final.python3.pkgs;
      howdy = let
        pythonDeps = builtins.map (
          dep:
            if dep == "opencv4Full"
            then "opencv4"
            else dep
        );
      in
        (prev.howdy.override {inherit (final) python3;}).overrideAttrs (oldAttrs: {
          pythonEnv = final.python3.buildEnv.override {
            extraLibs = final.lib.attrVals (pythonDeps oldAttrs.passthru.pythonDeps) final.python3.pkgs;
            makeWrapperArgs = [
              "--set"
              "OMP_NUM_THREADS"
              "1"
            ];
          };
          passthru =
            oldAttrs.passthru
            // {
              pythonDeps = pythonDeps oldAttrs.passthru.pythonDeps;
            };
        });
    })
  ];

  nixpkgs.config.allowUnfree = true;
}
