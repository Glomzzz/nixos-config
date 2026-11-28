# Declares the dotfiles links and the login-time credential render.
# Targets are out-of-store symlinks into the repo working tree, so editing a tracked
# file takes effect without a rebuild. The render needs the YubiKey (saved PIN, touch per
# decrypt) and writes only to $XDG_RUNTIME_DIR; the agent directory links point there.
#
# Activation: `force` replaces the symlinks made by hand (same targets). Credentials and
# the root-owned skills directory are not declared here.
{
  config,
  lib,
  pkgs,
  ...
}: let
  repo = "${config.home.homeDirectory}/nixos-config/dotfiles";
  renderPi = pkgs.writeShellApplication {
    name = "pi-render-secrets";
    runtimeInputs = [pkgs.sops pkgs.jq pkgs.coreutils pkgs.gnupg];
    text = builtins.readFile ../../../scripts/pi-render-secrets;
  };
in {
  home.file.".pi/agent" = {
    source = config.lib.file.mkOutOfStoreSymlink "${repo}/pi/agent";
    force = true;
  };

  xdg.configFile."cortexkit" = {
    source = config.lib.file.mkOutOfStoreSymlink "${repo}/cortexkit";
    force = true;
  };

  xdg.configFile."emacs" = {
    source = config.lib.file.mkOutOfStoreSymlink "${repo}/emacs";
    force = true;
  };

  systemd.user.services.pi-render-secrets = {
    Unit = {
      Description = "Render pi credentials from nixos-secrets and link them into the agent directory";
      PartOf = ["graphical-session.target"];
      After = ["graphical-session.target"];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      Environment = ["PI_AGENT_DIR=${repo}/pi/agent"];
      ExecStart = "${renderPi}/bin/pi-render-secrets";
    };
    Install.WantedBy = ["graphical-session.target"];
  };
}
