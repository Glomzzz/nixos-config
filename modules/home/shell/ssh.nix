{
  lib,
  pkgs,
  username,
  ...
}: let
  identity = import (../../../users + "/${username}/openpgp.nix");
in {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        IdentitiesOnly = true;
        ForwardAgent = false;
      };
      # A public IdentityFile selects the matching private key in gpg-agent.
      # Avoid silently falling back to unrelated software keys in the agent.
      # mac-mini is excluded: it uses a software key and must not load this.
      "* !macmini !mac-mini" = {
        IdentityFile = "~/.ssh/yubikey-openpgp.pub";
      };
      "macmini mac-mini" = {
        # Software key, no agent: avoids YubiKey touch prompts for this host.
        IdentityFile = "~/.ssh/id_ed25519";
        IdentityAgent = "none";
        hostname = "mac-mini";
        proxyCommand = "${pkgs.ssh-proxy-mac-mini} %p %h";
        serverAliveInterval = 30;
        serverAliveCountMax = 3;
      };
    };
  };

  home.file = {
    ".ssh/config".force = true;
    ".ssh/yubikey-openpgp.pub".source = identity.sshPublicKeyFile;
  };

  home.activation.installPrivateSshConfig = lib.hm.dag.entryAfter ["linkGeneration"] ''
    config_path="$HOME/.ssh/config"

    run mkdir -p $VERBOSE_ARG "$HOME/.ssh"
    run chmod 700 "$HOME/.ssh"

    if [[ -L "$config_path" ]]; then
      # OpenSSH rejects configs owned by the store build user.
      source_path="$(readlink -f "$config_path")"
      run rm $VERBOSE_ARG "$config_path"
      run install -m 600 "$source_path" "$config_path"
    elif [[ -e "$config_path" ]]; then
      run chmod 600 "$config_path"
    fi
  '';
}
