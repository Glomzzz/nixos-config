{
  lib,
  writeShellScript,
  gawk,
  glibc,
  gnugrep,
  iproute2,
  libressl,
  tailscale,
}: let
  awk = lib.getExe' gawk "awk";
  getent = lib.getExe' glibc.bin "getent";
  grep = lib.getExe' gnugrep "grep";
  ip = lib.getExe' iproute2 "ip";
  nc = lib.getExe' libressl.nc "nc";
  tailscaleExe = lib.getExe' tailscale "tailscale";
in
  writeShellScript "ssh-proxy-mac-mini" ''
    set -eu

    port="$1"
    host="$2"
    lan_host="mac-mini.local"
    lan_ip_fallback="192.168.50.198"

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

    tailscale_ip="$(${tailscaleExe} ip -4 "$host")"
    exec ${nc} -n "$tailscale_ip" "$port"
  ''
