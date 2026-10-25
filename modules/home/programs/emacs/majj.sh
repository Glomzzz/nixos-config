#!/bin/sh
# Open Majutsu in a blocking terminal client of the managed Emacs daemon.
set -eu

usage() {
  echo 'Usage: majj [DIRECTORY]'
}

if [ "$#" -gt 1 ]; then
  usage >&2
  exit 2
fi
if [ "$#" -eq 1 ]; then
  case "$1" in
    -h|--help) usage; exit 0 ;;
    *) cd -- "$1" ;;
  esac
fi

# Emacsclient supplies its cwd as default-directory, including for --eval.
# Keep --tty after --eval so emc also applies its TTY/Kitty handoff policy.
exec '@emc@' --eval '(progn (require (quote majutsu)) (majutsu-log default-directory) (delete-other-windows))' --tty --suppress-output
