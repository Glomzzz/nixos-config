{pkgs, ...}: let
  hyprlandOnly = ''${pkgs.systemd}/lib/systemd/systemd-xdg-autostart-condition "Hyprland" ""'';
  unlockKWallet = pkgs.writeShellApplication {
    name = "unlock-kwallet";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.systemd
    ];
    text = ''
      wallet_path=/org/freedesktop/secrets/collection/kdewallet
      unlock_result="$(
        busctl --user --json=short call \
          org.freedesktop.secrets \
          /org/freedesktop/secrets \
          org.freedesktop.Secret.Service \
          Unlock ao 1 "$wallet_path"
      )"
      prompt="$(jq -er '.data[1] | strings' <<<"$unlock_result")"

      if [[ "$prompt" != / ]]; then
        busctl --user call \
          org.freedesktop.secrets \
          "$prompt" \
          org.freedesktop.Secret.Prompt \
          Prompt s "" >/dev/null
      fi

      for ((attempt = 0; attempt < 50; attempt++)); do
        locked="$(
          busctl --user --json=short get-property \
            org.freedesktop.secrets \
            "$wallet_path" \
            org.freedesktop.Secret.Collection \
            Locked \
            | jq -r '.data'
        )"
        if [[ "$locked" == false ]]; then
          exit 0
        fi
        sleep 0.1
      done

      echo "KWallet remained locked after the passwordless unlock request" >&2
      exit 1
    '';
  };
in {
  programs.nm-applet = {
    enable = true;
    indicator = true;
  };

  systemd.user.services = {
    # The Secret Service must own its bus name and open the passwordless wallet
    # before NetworkManager asks its user agent for an agent-owned Wi-Fi key.
    ksecretd = {
      description = "KWallet Secret Service";
      wantedBy = ["graphical-session.target"];
      partOf = ["graphical-session.target"];
      after = ["wayland-session-waitenv.service"];
      before = [
        "graphical-session.target"
        "nm-applet.service"
        "xdg-desktop-portal.service"
      ];
      serviceConfig = {
        Type = "dbus";
        BusName = "org.freedesktop.secrets";
        ExecCondition = hyprlandOnly;
        ExecStart = "${pkgs.kdePackages.kwallet}/bin/ksecretd";
        ExecStartPost = "-${unlockKWallet}/bin/unlock-kwallet";
        Restart = "on-failure";
        RestartSec = 1;
        Slice = "session.slice";
        TimeoutStartSec = 10;
      };
    };

    nm-applet = {
      wants = ["ksecretd.service"];
      after = ["ksecretd.service"];
      serviceConfig = {
        ExecCondition = hyprlandOnly;
        Restart = "on-failure";
        RestartSec = 3;
      };
    };
  };

  networking = {
    networkmanager.enable = true;
    firewall.enable = true;
    firewall = {
      checkReversePath = "loose";
    };

    nameservers = [
      "1.1.1.1"
      "8.8.8.8"
    ];
  };
}
