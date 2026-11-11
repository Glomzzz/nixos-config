{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  boost,
  gettext,
  pkg-config,
  fcitx5,
  libime,
  nlohmann_json,
  phono-core,
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

  cmakeFlags = [
    (lib.cmakeBool "BUILD_TESTING" false)
    (lib.cmakeBool "PHONO_BUNDLE_CORE" false)
    (lib.cmakeFeature "PHONO_SDK_PREFIX" "${phono-core}")
    (lib.cmakeFeature "PHONO_PINYIN_DICT" "${libime}/share/libime/sc.dict")
    (lib.cmakeFeature "PHONO_FCITX_ADDON_DIR" "lib/fcitx5")
    (lib.cmakeFeature "PHONO_FCITX_DATA_DIR" "share/fcitx5")
  ];

  meta = {
    description = "Local neural Pinyin and Shuangpin input methods for Fcitx5";
    homepage = "https://github.com/phono-project/phono-fcitx5-addon";
    license = lib.licenses.apache20;
    platforms = ["x86_64-linux"];
  };
}
