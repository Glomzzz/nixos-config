{pkgs, ...}: let
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

  # cliphist itself has no picker UI, so pair it with fuzzel in dmenu mode.
  # Bound in settings.nix via this script rather than a long inline command.
  home.packages = [
    (pkgs.writeShellScriptBin "clipboard-history" ''
      set -euo pipefail
      ${cliphist} list \
        | ${fuzzel} --dmenu --prompt '  ' --width 60 \
        | ${cliphist} decode \
        | ${wlCopy}
    '')
  ];
}
