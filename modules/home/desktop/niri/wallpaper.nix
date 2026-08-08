{pkgs, ...}: let
  wallpaper = ../../../../assets/wallpaper_1.png;
in {
  # `swww` was renamed to `awww` in nixpkgs (alias added 2026-03-22), and the
  # Home Manager module followed: services.swww is now services.awww. The old
  # names still resolve through deprecation shims, but are spelled out properly
  # here so no warnings appear on rebuild.
  # `--layer background` is already the daemon default, so no extra args are
  # needed here.
  services.awww.enable = true;

  # The daemon starts with no image loaded, so the wallpaper has to be set once
  # its socket exists. awww.service is a plain `simple` unit, so ordering after
  # it does not guarantee the socket is accepting connections yet - hence the
  # short retry rather than a bare one-shot call.
  systemd.user.services.awww-wallpaper = {
    Unit = {
      Description = "Set the desktop wallpaper with awww";
      ConditionEnvironment = "WAYLAND_DISPLAY";
      After = ["awww.service"];
      Requires = ["awww.service"];
      PartOf = ["graphical-session.target"];
    };

    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = let
        awww = "${pkgs.awww}/bin/awww";
        setWallpaper = pkgs.writeShellScript "awww-set-wallpaper" ''
          for _ in $(seq 1 50); do
            if ${awww} query >/dev/null 2>&1; then
              exec ${awww} img ${wallpaper} \
                --transition-type fade \
                --transition-duration 1 \
                --resize crop \
                --filter Lanczos3
            fi
            sleep 0.1
          done
          echo "awww-daemon did not become ready in time" >&2
          exit 1
        '';
      in "${setWallpaper}";
    };

    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };
}
