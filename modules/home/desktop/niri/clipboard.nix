{
  config,
  pkgs,
  ...
}: let
  cliphist = "${pkgs.cliphist}/bin/cliphist";
  fuzzel = "${pkgs.fuzzel}/bin/fuzzel";
  wlCopy = "${pkgs.wl-clipboard}/bin/wl-copy";
in {
  # Plasma's clipboard applet kept history for us; cliphist does that here. The
  # module runs two wl-paste watchers (text and images) against a small store.
  services.cliphist = {
    enable = true;
    allowImages = true;
  };

  # QQ and WeChat mix native Wayland windows with X11 clipboard access. The
  # satellite's wl_data_device bridge only sees offers while an X11 surface
  # has focus, so pasting into those native windows can read a stale selection.
  # clipferry watches data-control/XFIXES instead, preserving all MIME types
  # and backstopping the satellite without polling or ownership feedback loops.
  systemd.user.services.clipferry = {
    Unit = {
      Description = "X11 and Wayland clipboard bridge";
      After = [config.wayland.systemd.target];
      PartOf = [config.wayland.systemd.target];
      StartLimitIntervalSec = 0;
    };
    Service = {
      ExecStart = "${pkgs.clipferry}/bin/clipferry --skip-sensitive";
      Restart = "always";
      RestartSec = 1;
      RestartSteps = 5;
      RestartMaxDelaySec = 30;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      RestrictAddressFamilies = ["AF_UNIX"];
      # Keep /tmp/.X11-unix visible; the bridge needs the satellite's socket.
      # clipferry also applies its own Landlock sandbox after connecting.
    };
    Install.WantedBy = [config.wayland.systemd.target];
  };

  # cliphist itself has no picker UI, so pair it with fuzzel in dmenu mode.
  # Bound in settings.nix via this script rather than a long inline command.
  home.packages = [
    pkgs.clipferry
    (pkgs.writeShellScriptBin "clipboard-history" ''
      set -euo pipefail
      ${cliphist} list \
        | ${fuzzel} --dmenu --prompt '  ' --width 60 \
        | ${cliphist} decode \
        | ${wlCopy}
    '')
  ];
}
