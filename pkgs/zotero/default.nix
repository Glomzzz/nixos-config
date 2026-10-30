# Zotero built from upstream main (unreleased 11.0 development line), pinned
# to a specific commit. The latest tagged release (10.0.7) and nixpkgs
# (10.0.4) still build against Firefox ESR 140, which is end-of-life, so this
# package uses the Firefox 153 ESR runtime from ./firefox-esr-153-bin.nix.
#
# Refresh: bump `rev`, then set both hashes to lib.fakeHash and rebuild to
# read the new values from the mismatch errors.
{
  lib,
  buildNpmPackage,
  callPackage,
  copyDesktopItems,
  fetchFromGitHub,
  gawk,
  giflib,
  libGL,
  makeDesktopItem,
  nodejs_22,
  pango,
  pciutils,
  perl,
  pkg-config,
  python3,
  rsync,
  speechd-minimal,
  unzip,
  wrapGAppsHook3,
  xz,
  zip,
}: let
  # Node 22, not 24: npm 11.19 bundled with Node 24 skips install scripts that
  # are not on the allowScripts list, so the zotero/prosemirror-math git
  # dependency never builds its dist/ and note-editor fails to bundle.
  nodejs = nodejs_22;

  firefox = callPackage ./firefox-esr-153-bin.nix {};

  pname = "zotero";
  version = "11.0-unstable-2026-10-29";
  rev = "212a7d6a585d1209bc4e698a904490205f139500";

  src = fetchFromGitHub {
    owner = "zotero";
    repo = "zotero";
    inherit rev;
    fetchSubmodules = true;
    hash = "sha256-AHxS2MUyEykP92Dqw2LFD+XGZZLdmbFA4LgmRg6lIsI=";
  };

  pdf-js = buildNpmPackage {
    pname = "zotero-pdf-js";
    inherit version nodejs;
    src = "${src}/reader/pdfjs/pdf.js";
    npmDepsHash = "sha256-xq0RhCruM22mFC3zkHpn4hX8YdO32Sn42fbSC0cQXFw=";
    buildPhase = ''
      runHook preBuild

      npm exec gulp generic
      npm exec gulp generic-legacy
      npm exec gulp minified-legacy

      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -r . $out

      runHook postInstall
    '';
  };

  epub-js = buildNpmPackage {
    pname = "zotero-epub-js";
    inherit version nodejs;
    src = "${src}/reader/epubjs/epub.js";
    npmDepsHash = "sha256-6XY6uczPOpMpRHDQbkQRHKBDDRQ/MXIVepGBx1V+h5Q=";
    buildPhase = ''
      runHook preBuild

      npm run compile
      npm run build

      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -r . $out

      runHook postInstall
    '';
  };

  pdf-reader = buildNpmPackage {
    pname = "zotero-pdf-reader";
    inherit version nodejs;
    src = "${src}/reader";
    npmDepsHash = "sha256-/Szv0BWy9zHLrusRxo8XRtfyFmq/rS4GG1iO7NkV2BQ=";
    patches = [
      ./pdf-reader-locales.patch
      ./pdf-reader-build-fix.patch
    ];
    postPatch = ''
      rm -rf pdfjs/pdf.js
      cp -r ${pdf-js} pdfjs/pdf.js
      chmod -R u+w pdfjs/pdf.js

      rm -rf epubjs/epub.js
      cp -r ${epub-js} epubjs/epub.js
      chmod -R u+w epubjs/epub.js

      mkdir -p locales/en-US/
      cp -r ${src}/chrome/locale/en-US/zotero/* locales/en-US/
    '';
    npmBuildScript = "build:zotero";
    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -r . $out

      runHook postInstall
    '';
  };

  document-worker = buildNpmPackage {
    pname = "zotero-document-worker";
    inherit version nodejs;
    src = "${src}/document-worker";
    npmDepsHash = "sha256-dUGZ0RsmW+cAXPi78W9eX7kQnTiCVc8K9lPPtw8Cif0=";
    nativeBuildInputs = [
      rsync
      pkg-config
    ];
    buildInputs = [
      pango
      giflib
    ];
    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -r . $out

      runHook postInstall
    '';
  };

  note-editor = buildNpmPackage {
    pname = "zotero-note-editor";
    inherit version nodejs;
    src = "${src}/note-editor";
    npmDepsHash = "sha256-krUkGXQEK48iUyU7PV/m0RcdCbmtrL2Q5UL1SWfPhk8=";
    makeCacheWritable = true;
    patches = [./pdf-reader-locales.patch];
    postPatch = ''
      mkdir -p locales/en-US/
      cp -r ${src}/chrome/locale/en-US/zotero/* locales/en-US/
    '';
    installPhase = ''
      runHook preInstall

      mkdir -p $out
      cp -r . $out

      runHook postInstall
    '';
  };
in
  buildNpmPackage (finalAttrs: {
    inherit
      pname
      version
      src
      nodejs
      ;

    npmDepsHash = "sha256-ACSeBh7QpWxznQiUoqTSWeeItLQwaeP5Ji25Cjy4PwQ=";

    nativeBuildInputs = [
      perl
      python3
      zip
      unzip
      xz
      gawk
      rsync
      copyDesktopItems
      wrapGAppsHook3
    ];

    patches = [
      ./avoid-git.patch
      ./js-build-fixes.patch
      ./avoid-xulrunner-fetch.patch
      ./build-fixes.patch
      ./libreoffice-optdir.patch
    ];

    postPatch = ''
      rm -rf reader
      cp -r ${pdf-reader} reader
      chmod -R u+w reader

      rm -rf document-worker
      cp -r ${document-worker} document-worker
      chmod -R u+w document-worker

      rm -rf note-editor
      cp -r ${note-editor} note-editor
      chmod -R u+w note-editor

      patchShebangs --build app/
    '';

    buildPhase = ''
      runHook preBuild

      npm run build

      # Place the Gecko runtime where app/scripts/fetch_xulrunner expects it.
      mkdir -p app/xulrunner/
      cp -r "${firefox}/lib/${firefox.libName}" "app/xulrunner/firefox-linux-x86_64"
      chmod -R u+w app/xulrunner/

      build_dir=$(mktemp -d)
      ./app/scripts/prepare_build -s ./build -o "$build_dir" -c release
      ./app/build.sh -d "$build_dir" -c release -s -p l -a x64

      runHook postBuild
    '';

    desktopItems = [
      (makeDesktopItem {
        name = "zotero";
        exec = "zotero -url %U";
        icon = "zotero";
        comment = finalAttrs.meta.description;
        desktopName = "Zotero";
        genericName = "Reference Management";
        categories = [
          "Office"
          "Database"
        ];
        startupNotify = true;
        mimeTypes = [
          "x-scheme-handler/zotero"
          "text/plain"
        ];
      })
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/
      cp -r app/staging/*/. $out/lib/

      mkdir -p $out/bin/
      ln -s ../lib/zotero $out/bin/zotero

      for size in 32 64 128; do
        install -Dm444 "app/linux/icons/icon''${size}.png" "$out/share/icons/hicolor/''${size}x''${size}/apps/zotero.png"
      done
      install -Dm444 "app/linux/icons/symbolic.svg" "$out/share/icons/hicolor/scalable/apps/zotero-symbolic.svg"

      runHook postInstall
    '';

    preFixup = ''
      gappsWrapperArgs+=(--suffix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          libGL
          pciutils
          speechd-minimal
        ]
      })
    '';

    meta = {
      homepage = "https://www.zotero.org";
      description = "Collect, organize, cite, and share your research sources";
      changelog = "https://www.zotero.org/support/changelog";
      mainProgram = "zotero";
      license = lib.licenses.agpl3Only;
      platforms = ["x86_64-linux"];
    };
  })
