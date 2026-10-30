{pkgs}:
pkgs.runCommand "nix-credentials-check"
{
  nativeBuildInputs = [pkgs.python3 pkgs.bash pkgs.coreutils pkgs.shellcheck];
}
''
  export PYTHONDONTWRITEBYTECODE=1
  shellcheck ${../scripts/with-github-token}
  bash -n ${../scripts/with-github-token}
  python3 ${../scripts/tests/nix-credentials.py} \
    ${../scripts/with-github-token} ${../scripts/remove-nix-access-tokens.py}
  touch "$out"
''
