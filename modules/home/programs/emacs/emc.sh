#!/bin/sh
# Managed client: prefer a blocking TTY, never spawn an unmanaged daemon.
set -eu

if [ -n "${EMACSCLIENT:-}" ] && [ -x "$EMACSCLIENT" ]; then
  client=$EMACSCLIENT
elif [ -x '@emacsclient@' ]; then
  client='@emacsclient@'
else
  client=$(command -v emacsclient || true)
fi
[ -n "$client" ] || { echo 'emc: emacsclient not found' >&2; exit 1; }

frontend='tty'
explicit=no
skip=no
no_wait=no
for argument do
  if [ "$skip" = yes ]; then skip=no; continue; fi
  case "$argument" in
    --) break ;;
    -s|--socket-name|-f|--server-file|-a|--alternate-editor) skip=yes ;;
    -c|--create-frame|-r|--reuse-frame) frontend=gui; explicit=yes ;;
    -d|--display) frontend=gui; explicit=yes; skip=yes ;;
    --display=*) frontend=gui; explicit=yes ;;
    -t|--tty) frontend='tty'; explicit=yes ;;
    -e|--eval) frontend=control; explicit=yes; skip=yes ;;
    --eval=*) frontend=control; explicit=yes ;;
    -n|--no-wait) no_wait=yes ;;
    -h|--help|-V|--version) exec "$client" "$@" ;;
  esac
done
[ "$explicit" = yes ] || set -- --tty "$@"
if [ "$frontend" = tty ]; then
  if [ "$no_wait" = yes ]; then
    echo 'emc: TTY clients must wait; use --create-frame with --no-wait' >&2
    exit 1
  fi
  if ! [ -t 0 ] || ! [ -t 1 ]; then
    if [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
      echo 'emc: no terminal or desktop display; attach a TTY first' >&2
      exit 1
    fi
    # Desktop launches and GUI editor callers do not own a controlling TTY.
    # Wait for this Kitty window, so Git/sudoedit keep their blocking contract.
    exec '@kitty@' --class emacs-terminal "$0" "$@"
  fi
fi

no_spawn_editor='@noSpawnEditor@'
systemctl='@systemctl@'
probe=$("$client" --timeout=5 --alternate-editor="$no_spawn_editor" \
  --eval '(if (fboundp (quote emc/launcher-state)) (emc/launcher-state) (quote unverified))' \
  2>/dev/null || true)
case "$probe" in
  ok) ;;
  stale)
    "$systemctl" --user reset-failed emacs.service >/dev/null 2>&1 || true
    "$systemctl" --user restart emacs.service || {
      echo 'emc: failed to restart emacs.service' >&2; exit 1;
    }
    ;;
  *)
    # An unanswered probe does not prove the daemon is safe to kill.
    if "$systemctl" --user --quiet is-active emacs.service; then
      echo 'emc: active daemon could not be verified; refusing to restart it' >&2
      exit 1
    fi
    "$systemctl" --user reset-failed emacs.service >/dev/null 2>&1 || true
    "$systemctl" --user start emacs.service || {
      echo 'emc: failed to start emacs.service' >&2; exit 1;
    }
    ;;
esac
exec "$client" --alternate-editor="$no_spawn_editor" "$@"
