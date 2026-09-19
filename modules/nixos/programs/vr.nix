{
  pkgs,
  username,
  ...
}: let
  # Steam's compositor launcher is user-owned and mutable (Steam updates it
  # in place). A file capability makes the dynamic loader enter secure-exec
  # mode, where it ignores the Nix library path and cannot load libcap.so.2.
  # Clear that capability and use the explicit realtime limits below instead.
  steamVrLauncher = "/home/${username}/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrcompositor-launcher";
  # vrsetup.sh runs before every SteamVR compositor launch and restores
  # CAP_SYS_NICE with pkexec when getcap reports no capability. That file
  # capability puts the launcher in secure-exec mode, which strips the host
  # library path and makes libcap.so.2 unavailable on NixOS. Report the
  # expected capability only for this SteamVR launcher, while delegating all
  # other getcap calls to the real tool.
  #
  # The same shim is also installed through security.wrappers below: SteamVR's
  # vrsetup.sh is relaunched at host level via Steam's launcher service, whose
  # bwrap sandbox remounts /run/wrappers nosuid, so pkexec can never grant the
  # capability there. /run/wrappers/bin is the first PATH entry inside that
  # sandbox (shadowing the steam-fhsenv /usr/bin/getcap), which makes the
  # getcap check short-circuit before pkexec is ever attempted.
  steamVrGetcap = pkgs.writeShellScriptBin "getcap" ''
    #!/usr/bin/env bash
    set -euo pipefail

    if [[ "''${1:-}" == */SteamVR/bin/linux64/vrcompositor-launcher ]]; then
      printf '%s cap_sys_nice=eip\n' "$1"
      exit 0
    fi

    exec ${pkgs.libcap}/bin/getcap "$@"
  '';
  steamVrClearCapability = pkgs.writeShellScript "steamvr-clear-cap-sys-nice" ''
    set -eu

    launcher="${steamVrLauncher}"
    current="$(${pkgs.libcap}/bin/getcap "$launcher" 2>/dev/null || true)"
    case "$current" in
      *cap_sys_nice*)
        exec ${pkgs.libcap}/bin/setcap -r "$launcher"
        ;;
      *) exit 0 ;;
    esac
  '';
in {
  # SteamVR and the encoder run in the interactive user session, so GameMode
  # is a better fit than a permanently forced performance governor.
  programs.gamemode = {
    enable = true;
    settings.general = {
      # GameMode accepts 0..20 and negates this value for the game process.
      renice = 10;
      desiredgov = "performance";
    };
  };

  # GameMode's polkit rule only allows users in this group to request a
  # performance session. Without it gamemoderun silently falls back to the
  # normal powersave policy.
  users.users.${username}.extraGroups = ["gamemode"];

  # SteamVR is launched from the niri user session. The default systemd user
  # limits (RTPRIO=0 and an 8 MiB memlock cap) prevent its compositor and
  # encoder threads from using realtime scheduling, which shows up as head
  # pose desync under load.
  # Steam is normally started by the graphical login, not as a systemd user
  # service. PAM limits ensure that this interactive process and its children
  # inherit the same scheduling and locked-memory budget as user services.
  # The compositor requests SCHED_RR at the maximum priority (99), so the
  # limit must be 99; the previous 95 left every realtime attempt failing with
  # EPERM (strace: sched_setscheduler(..., SCHED_RR, {sched_priority=99}) = -1
  # EPERM), which is what made the head-tracked view desync under load.
  security = {
    pam.loginLimits = [
      {
        domain = username;
        item = "rtprio";
        type = "-";
        value = "99";
      }
      {
        domain = username;
        item = "nice";
        type = "-";
        value = "-20";
      }
      {
        domain = username;
        item = "memlock";
        type = "-";
        value = "infinity";
      }
    ];

    polkit.enablePkexecWrapper = true;

    # See the steamVrGetcap comment: SteamVR's vrsetup.sh runs inside Steam's
    # launcher-service sandbox, where /run/wrappers is mounted nosuid and pkexec
    # fails with "pkexec must be setuid root", aborting setup with "SteamVR setup
    # is incomplete". getcap is read-only (it only reports file capabilities), so
    # running the shim with a setuid wrapper is harmless; inside the sandbox the
    # setuid bit is ignored anyway and it runs as the plain user.
    wrappers.getcap = {
      source = "${steamVrGetcap}/bin/getcap";
      owner = "root";
      group = "root";
      setuid = true;
    };
  };

  systemd = {
    user.settings.Manager = {
      DefaultLimitRTPRIO = 99;
      DefaultLimitNICE = -20;
      DefaultLimitMEMLOCK = "infinity";
    };

    # The unit name intentionally differs from the old CAP_SYS_NICE grant
    # service. This lets the activation script below stop the old path/timer
    # before systemd tries to start the new generation.
    services.steamvr-clear-cap-sys-nice = {
      description = "Clear SteamVR compositor CAP_SYS_NICE file capability";
      unitConfig.ConditionPathExists = steamVrLauncher;
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = steamVrClearCapability;
      };
    };

    # Steam may restore the capability while updating this user-owned binary.
    # Poll idempotently instead of watching the file: setcap itself changes
    # file metadata, which made the old PathChanged unit trigger in a loop.
    timers.steamvr-clear-cap-sys-nice = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitActiveSec = "30s";
        Unit = "steamvr-clear-cap-sys-nice.service";
      };
    };
  };

  # The previous generations installed steamvr-cap-sys-nice.path and a
  # granting service. Disable those units before the new unit graph is
  # activated; otherwise the old path can repeatedly reapply the capability
  # during the switch and make nixos-rebuild fail with start-limit-hit.
  system.activationScripts.steamvrCapSysNiceMigration = {
    deps = [];
    text = ''
      for unit in steamvr-cap-sys-nice.path steamvr-cap-sys-nice.service steamvr-cap-sys-nice.timer; do
        ${pkgs.systemd}/bin/systemctl disable --now "$unit" 2>/dev/null || true
        ${pkgs.systemd}/bin/systemctl reset-failed "$unit" 2>/dev/null || true
      done
    '';
  };
}
