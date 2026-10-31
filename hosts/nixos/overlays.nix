_: {
  nixpkgs.overlays = [
    (import ../../pkgs)
    (_: prev: {
      # patchelf 0.19 corrupts this non-PIE binary (linked at 0x400000) when one
      # run both replaces the interpreter and grows RUNPATH: the writable segment
      # it creates overlaps the read-only first PT_LOAD, so ld.so segfaults in
      # dl_main at startup. Setting RUNPATH first keeps the segments disjoint.
      anydesk = prev.anydesk.overrideAttrs (oldAttrs: {
        postFixup = ''
          patchelf --set-rpath "${prev.lib.makeLibraryPath oldAttrs.buildInputs}" $out/bin/anydesk
          patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/anydesk

          wrapProgram $out/bin/anydesk \
            --prefix PATH : ${prev.lib.makeBinPath [prev.lsb-release prev.pciutils]} \
            --prefix GDK_BACKEND : x11 \
            --suffix PATH : ${prev.lib.makeBinPath [prev.net-tools]} \
            --set GTK_THEME Adwaita
        '';
      });
    })
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
