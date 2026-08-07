{
  lib,
  pkgs,
  ...
}: {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "macmini mac-mini" = {
        hostname = "mac-mini";
        proxyCommand = "${pkgs.ssh-proxy-mac-mini} %p %h";
        serverAliveInterval = 30;
        serverAliveCountMax = 3;
      };
    };
  };

  home.file.".ssh/config".force = true;

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
