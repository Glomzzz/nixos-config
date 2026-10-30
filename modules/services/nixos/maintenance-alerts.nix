{
  config,
  pkgs,
  username,
  ...
}: let
  uid = toString config.users.users.${username}.uid;
  runtime = "/run/user/${uid}";
  alert = pkgs.writeShellApplication {
    name = "maintenance-failure-alert";
    runtimeInputs = [pkgs.libnotify];
    text = ''
      unit="$1"
      printf 'Maintenance failed: %s; inspect journalctl -u %s\n' "$unit" "$unit"
      if [[ -S ${runtime}/bus ]]; then
        notify-send --urgency=critical "Maintenance failed" \
          "$unit failed. Inspect its system journal." || true
      fi
    '';
  };
in {
  # Original failures remain in the system journal even without a desktop.
  systemd.services."maintenance-alert@" = {
    description = "Desktop notification for failed maintenance unit %i";
    environment.DBUS_SESSION_BUS_ADDRESS = "unix:path=${runtime}/bus";
    serviceConfig = {
      Type = "oneshot";
      User = username;
      ExecStart = "${alert}/bin/maintenance-failure-alert %i";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
    };
  };
}
