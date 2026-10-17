{
  config,
  pkgs,
  ...
}: let
  emacs = config.programs.emacs.finalPackage;
  noSpawnEditor = "${pkgs.coreutils}/bin/false";
in {
  # emacsclient wrapper used by the niri binds and the Dirvish launcher:
  # when the hand-written config is newer than the running daemon and no
  # frame is open (the launching client is the only one), restart the
  # daemon first so the edited config is loaded.
  #
  # The probe only asks for functions defined by modules/emc.el.
  # a daemon that cannot answer it is running some other config and
  # counts as stale, so the restart that loads the current config
  # always happens instead of serving void-function errors.
  home.file.".local/bin/emc" = {
    executable = true;
    text = ''
      #!/bin/sh
      # Resolve the client at runtime instead of relying on a bare
      # store path: prefer an explicit EMACSCLIENT, then the binary of
      # the generation this wrapper was built from, and fall back to
      # PATH.  A rolled-back or garbage-collected Emacs store path can
      # therefore never leave the wrapper broken.
      if [ -n "$EMACSCLIENT" ] && [ -x "$EMACSCLIENT" ]; then
        emacsclient=$EMACSCLIENT
      elif [ -x "${emacs}/bin/emacsclient" ]; then
        emacsclient=${emacs}/bin/emacsclient
      else
        emacsclient=$(command -v emacsclient || true)
      fi
      [ -n "$emacsclient" ] || { echo "emc: emacsclient not found" >&2; exit 1; }

      no_spawn_editor=${noSpawnEditor}
      # A daemon blocked by an earlier asynchronous request must not make
      # every later launcher wait forever.  A failed health probe triggers
      # the managed service restart below.
      probe=$("$emacsclient" --timeout=5 --alternate-editor="$no_spawn_editor" --eval '(if (and (fboundp (quote emc/gui-frames)) (fboundp (quote emc/config-stale-p))) (if (and (null (emc/gui-frames)) (emc/config-stale-p)) (quote stale) (quote ok)) (quote stale))' 2>/dev/null || true)

      # systemctl lives at the stable system path (/run/current-system
      # is a boot-level GC root), unlike a per-generation store path.
      systemctl=/run/current-system/sw/bin/systemctl
      if [ "$probe" != ok ]; then
        "$systemctl" --user reset-failed emacs.service >/dev/null 2>&1 || true
        if ! "$systemctl" --user restart emacs.service; then
          echo "emc: failed to restart emacs.service" >&2
          exit 1
        fi
      fi
      exec "$emacsclient" --alternate-editor="$no_spawn_editor" "$@"
    '';
  };

  # An empty alternate editor tells emacsclient to launch `emacs --daemon`.
  # Use `false` instead so every editor entry fails cleanly while the managed
  # service is unavailable and can never shadow its socket with an orphan.
  home.sessionVariables = {
    EDITOR = "emacsclient -c --alternate-editor=${noSpawnEditor}";
    VISUAL = "emacsclient -c --alternate-editor=${noSpawnEditor}";
    SUDO_EDITOR = "emacsclient -c --alternate-editor=${noSpawnEditor}";
    ALTERNATE_EDITOR = noSpawnEditor;
  };
}
