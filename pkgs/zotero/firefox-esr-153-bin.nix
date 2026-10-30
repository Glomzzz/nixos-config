# Prebuilt Firefox ESR 153 runtime for Zotero (x86_64-linux only).
# Matches GECKO_VERSION_LINUX in upstream app/config.sh. Adapted from the
# nixpkgs firefox-esr-140-bin derivation, which Zotero 10.x still uses and
# which is end-of-life.
{
  lib,
  stdenv,
  fetchurl,
  wrapGAppsHook3,
  autoPatchelfHook,
  alsa-lib,
  curl,
  dbus-glib,
  gtk3,
  libxtst,
  libva,
  pciutils,
  pipewire,
  adwaita-icon-theme,
  patchelfUnstable, # needed for --no-clobber-old-sections (Firefox relrhack)
}: let
  version = "153.6.0esr";

  binaryName = "firefox";

  # Hash from https://archive.mozilla.org/pub/firefox/releases/${version}/SHA256SUMS
  src = fetchurl {
    url = "mirror://mozilla/firefox/releases/${version}/linux-x86_64/en-US/firefox-${version}.tar.xz";
    hash = "sha256-MTIc2eLO9z32eEF+gQzdG1dgqlzIBjyEZWaeWGnLhJg=";
  };

  pname = "firefox-esr-153-bin-unwrapped";
in
  stdenv.mkDerivation {
    inherit pname version src;

    nativeBuildInputs = [
      wrapGAppsHook3
      autoPatchelfHook
      patchelfUnstable
    ];

    buildInputs = [
      gtk3
      adwaita-icon-theme
      alsa-lib
      dbus-glib
      libxtst
    ];

    runtimeDependencies = [
      curl
      pciutils
      libva.out
    ];

    appendRunpaths = [
      "${pipewire}/lib"
    ];

    patchelfFlags = ["--no-clobber-old-sections"];

    installPhase = ''
      mkdir -p "$prefix/lib/firefox-bin-${version}"
      cp -r * "$prefix/lib/firefox-bin-${version}"

      mkdir -p "$out/bin"
      ln -s "$prefix/lib/firefox-bin-${version}/firefox" "$out/bin/${binaryName}"
    '';

    passthru = {
      applicationName = "Firefox ESR";
      inherit binaryName;
      libName = "firefox-bin-${version}";
      withFFmpeg = true;
      withGSSAPI = true;
      inherit gtk3;
    };

    meta = {
      changelog = "https://www.firefox.com/en-US/firefox/${lib.removeSuffix "esr" version}/releasenotes/";
      description = "Mozilla Firefox ESR, free web browser (binary package, Zotero runtime)";
      homepage = "https://www.mozilla.org/firefox/";
      license = lib.licenses.mkLicense {
        shortName = "firefox";
        fullName = "Firefox Terms of Use";
        url = "https://www.mozilla.org/about/legal/terms/firefox/";
        free = false;
        redistributable = true;
      };
      sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
      platforms = ["x86_64-linux"];
      hydraPlatforms = [];
      mainProgram = binaryName;
    };
  }
