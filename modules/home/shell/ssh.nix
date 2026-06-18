{
  config,
  lib,
  pkgs,
  ...
}: let
  awk = lib.getExe' pkgs.gawk "awk";
  getent = lib.getExe' pkgs.glibc.bin "getent";
  grep = lib.getExe' pkgs.gnugrep "grep";
  ip = lib.getExe' pkgs.iproute2 "ip";
  nc = lib.getExe' pkgs.libressl.nc "nc";
  tailscale = lib.getExe' pkgs.tailscale "tailscale";
  macMiniProxy = pkgs.writeShellScript "ssh-proxy-mac-mini" ''
    set -eu

    port="$1"
    host="$2"
    lan_host="mac-mini.local"
    lan_ip_fallback="192.168.4.198"

    direct_lan_route() {
      route="$(${ip} -4 route get "$1" 2>/dev/null || true)"

      [ -n "$route" ] &&
        ! printf '%s\n' "$route" | ${grep} -Eq '(^| )via | dev tailscale0( |$)'
    }

    resolve_lan_ip() {
      ${getent} ahostsv4 "$lan_host" 2>/dev/null | ${awk} '
        !seen[$1]++ && $1 !~ /^100\./ { print $1; exit }
      '
    }

    try_lan_ip() {
      candidate="$1"

      [ -n "$candidate" ] || return 1
      direct_lan_route "$candidate" || return 1
      ${nc} -n -z -w 3 "$candidate" "$port" || return 1

      exec ${nc} -n "$candidate" "$port"
    }

    try_lan_ip "$(resolve_lan_ip)" || true
    try_lan_ip "$lan_ip_fallback" || true

    tailscale_ip="$(${tailscale} ip -4 "$host")"
    exec ${nc} -n "$tailscale_ip" "$port"
  '';
in {
  programs.ssh = {
    enable = true;
    settings = {
      "macmini mac-mini" = {
        hostname = "mac-mini";
        proxyCommand = "${macMiniProxy} %p %h";
        serverAliveInterval = 30;
        serverAliveCountMax = 3;
      };
    };
  };

  home.file.".ssh/config".force = true;

  home.activation.installPrivateSshConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
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
