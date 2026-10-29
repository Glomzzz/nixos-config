{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  boost,
  gettext,
  pkg-config,
  python3,
  fcitx5,
  libime,
  nlohmann_json,
  phono-core,
  qt6Packages,
}:
stdenv.mkDerivation rec {
  pname = "phono-fcitx5-addon";
  version = "0.1.3";

  src = fetchFromGitHub {
    owner = "phono-project";
    repo = "phono-fcitx5-addon";
    tag = "v${version}";
    hash = "sha256-OZfFJ/m8pngs/LNtgu+JHqJVQ1RZ6ZKIgLX8UcEoJy4=";
  };

  nativeBuildInputs = [cmake gettext pkg-config];
  buildInputs = [boost fcitx5 libime nlohmann_json phono-core];
  nativeCheckInputs = [python3];

  cmakeFlags = [
    (lib.cmakeBool "BUILD_TESTING" true)
    (lib.cmakeBool "PHONO_BUNDLE_CORE" false)
    (lib.cmakeFeature "PHONO_SDK_PREFIX" "${phono-core}")
    (lib.cmakeFeature "PHONO_PINYIN_DICT" "${libime}/share/libime/sc.dict")
    (lib.cmakeFeature "PHONO_FCITX_ADDON_DIR" "lib/fcitx5")
    (lib.cmakeFeature "PHONO_FCITX_DATA_DIR" "share/fcitx5")
  ];

  # The loader tests need the real punctuation/fullwidth addons, not /usr paths.
  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail '/usr/share/fcitx5' '${fcitx5}/share/fcitx5' \
      --replace-fail 'FCITX_ADDON_DIRS=''${CMAKE_CURRENT_BINARY_DIR}' 'FCITX_ADDON_DIRS=''${CMAKE_CURRENT_BINARY_DIR}:${qt6Packages.fcitx5-chinese-addons}/lib/fcitx5:${fcitx5}/lib/fcitx5' \
      --replace-fail 'FCITX_DATA_DIRS=''${CMAKE_CURRENT_BINARY_DIR}/data:' 'FCITX_DATA_DIRS=''${CMAKE_CURRENT_BINARY_DIR}/data:${qt6Packages.fcitx5-chinese-addons}/share/fcitx5:'
  '';

  doCheck = true;
  preCheck = ''
    export HOME="$TMPDIR"
  '';

  meta = {
    description = "Local neural Pinyin and Shuangpin input methods for Fcitx5";
    homepage = "https://github.com/phono-project/phono-fcitx5-addon";
    license = lib.licenses.apache20;
    platforms = ["x86_64-linux"];
  };
}
