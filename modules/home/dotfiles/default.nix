# Declares the dotfiles links. Targets are out-of-store symlinks into the repo working
# tree, so editing a file there takes effect without a rebuild.
#
# Activation: `force` replaces the symlinks made by hand during the switch (same targets).
# Credentials and the root-owned skills directory are not declared here; they are linked
# from ~/.pi/agent-legacy by hand until the sops render replaces them.
{
  config,
  lib,
  ...
}: let
  repo = "${config.home.homeDirectory}/nixos-config/dotfiles";
in {
  home.file.".pi/agent" = {
    source = config.lib.file.mkOutOfStoreSymlink "${repo}/pi/agent";
    force = true;
  };

  xdg.configFile."cortexkit" = {
    source = config.lib.file.mkOutOfStoreSymlink "${repo}/cortexkit";
    force = true;
  };
}
