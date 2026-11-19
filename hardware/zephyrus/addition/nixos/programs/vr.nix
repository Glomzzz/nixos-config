{
  config,
  lib,
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
  # security.wrappers requires an ELF target, even for a non-setuid shim.
  # Keep the launcher exception native rather than bypassing that validation.
  steamVrGetcap = pkgs.writeCBin "getcap" ''
    #include <stdio.h>
    #include <string.h>
    #include <unistd.h>

    int main(int argc, char **argv) {
      static const char suffix[] = "/SteamVR/bin/linux64/vrcompositor-launcher";
      static char real_getcap[] = "${pkgs.libcap}/bin/getcap";

      if (argc > 1) {
        size_t length = strlen(argv[1]);
        size_t suffix_length = sizeof(suffix) - 1;
        if (length >= suffix_length &&
            strcmp(argv[1] + length - suffix_length, suffix) == 0) {
          return printf("%s cap_sys_nice=eip\n", argv[1]) < 0 ? 1 : 0;
        }
      }

      argv[0] = real_getcap;
      execv(real_getcap, argv);
      perror(real_getcap);
      return 127;
    }
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

  # Restrict PAM allowances to the desktop user. niri-session actually starts
  # niri via systemd, so PAM limits alone do not reach compositor children;
  # explicit niri/WiVRn unit limits below preserve their VR scheduling budget
  # without raising soft defaults for every account and background service.
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
    # is incomplete". Keep the shim first in PATH via /run/wrappers, but it
    # only reports capabilities and needs neither root nor a setuid bit.
    wrappers.getcap = {
      source = "${steamVrGetcap}/bin/getcap";
      owner = "root";
      group = "root";
      setuid = false;
    };
  };

  systemd = {
    # The user manager must inherit sufficient hard ceilings to raise limits
    # for selected units. Keep its soft limits at normal defaults, and scope
    # the drop-in to this user's instance rather than user@.service globally.
    services."user@${toString config.users.users.${username}.uid}" = {
      overrideStrategy = "asDropin";
      enableDefaultPath = false;
      # Apply hard ceilings at the next boot, not by killing the live session.
      restartIfChanged = false;
      serviceConfig = {
        LimitRTPRIO = "0:99";
        LimitNICE = "0:40";
        LimitMEMLOCK = "8M:infinity";
      };
    };

    user.services = {
      # Preserve the vendor unit's ExecStart and session relationships.
      niri = {
        overrideStrategy = "asDropin";
        # Preserve the login environment imported by niri-session (fcitx5,
        # /run/wrappers, user packages), not NixOS's minimal service PATH.
        enableDefaultPath = false;
        restartIfChanged = false;
        unitConfig.ConditionUser = username;
        serviceConfig = {
          LimitRTPRIO = 99;
          LimitNICE = -20;
          LimitMEMLOCK = "infinity";
        };
      };
      wivrn = {
        unitConfig.ConditionUser = lib.mkForce username;
        serviceConfig = {
          LimitRTPRIO = 99;
          LimitNICE = -20;
          LimitMEMLOCK = "infinity";
        };
      };
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
