{
  lib,
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation {
  pname = "chinese-word-segmentation";
  version = "unstable-2025-09-03";

  # Upstream has no tags; the pin is the master commit reviewed for this package.
  # Submodules provide the vendored cppjieba and limonp sources cnws compiles against.
  src = fetchFromGitHub {
    owner = "kanglmf";
    repo = "emacs-chinese-word-segmentation";
    rev = "fd2e711dc7fd957267df5056a57575b3eb090ac4";
    fetchSubmodules = true;
    hash = "sha256-TnlrAA3KuQsBvmcc7yk0IKLpaSyJg8e1wGKBbF5b9pI=";
  };

  # The Makefile's default target builds only the stdin/stdout `cnws` helper.
  # The Emacs side (cns.el) is loaded from its Git source by ~/.config/emacs.
  installPhase = ''
    runHook preInstall

    install -Dm755 cnws "$out/bin/cnws"
    mkdir -p "$out/share/chinese-word-segmentation"
    cp -r cppjieba/dict "$out/share/chinese-word-segmentation/dict"

    runHook postInstall
  '';

  # Exercise the same line protocol cns.el uses, so a broken dictionary or
  # compiler fails the build instead of surfacing later inside Emacs.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    dict="$out/share/chinese-word-segmentation/dict"
    output=$(printf '中文分词\nEOF\n' | "$out/bin/cnws" \
      "$dict/jieba.dict.utf8" \
      "$dict/hmm_model.utf8" \
      "$dict/user.dict.utf8" \
      "$dict/idf.utf8" \
      "$dict/stop_words.utf8")
    printf '%s\n' "$output" | grep -qF '["中文", "分词"]: 2 2'

    runHook postInstallCheck
  '';

  meta = {
    description = "Jieba-based Chinese word segmentation helper for Emacs word motion";
    homepage = "https://github.com/kanglmf/emacs-chinese-word-segmentation";
    license = lib.licenses.gpl3Plus;
    mainProgram = "cnws";
    platforms = lib.platforms.unix;
  };
}
