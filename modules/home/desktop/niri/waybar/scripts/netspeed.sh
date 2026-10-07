INTERVAL="${INTERVAL:-1}"
# Virtual interfaces are excluded from BOTH the byte counters and the
# link lookup below, using the same list, so the rate and the tooltip
# always describe the same set of interfaces. tailscale0 is in the list
# because its counters double-count traffic that already passed through
# the physical link.
EXCLUDE='^(lo|docker|veth|br-|virbr|vnet|tun|tap|wg|zt|tailscale)'

sample() {
  awk -F'[: ]+' -v ex="$EXCLUDE" '
    NR > 2 { if ($2 ~ ex) next; rx += $3; tx += $11 }
    END    { printf "%d %d\n", rx, tx }
  ' /proc/net/dev
}

# The rate is scaled once and returned as two fields - magnitude and unit
# - so the caller can render it twice with different padding. The label
# needs a constant width; the tooltip reads like prose. One pre-padded
# string cannot satisfy both.
#
# The magnitude is held to the 0.0 shape (at most two integer digits),
# which is what fixes the label width: 99.9 is the largest value shown in
# any unit, and anything above it escalates to the next unit instead of
# growing a third digit, so 123.1 B renders as 0.1 KB.
#
# The guard is 99.95 rather than 100 because the comparison has to be made
# against the value that will be PRINTED, not the value held. %.1f rounds
# 99.96 up to "100.0" - three integer digits, one column too wide - so the
# escalation has to happen just below the rounding boundary.
#
# Units run to EB so the loop's counter, not the end of the list, is what
# stops the scaling: a 64-bit counter cannot exceed 16 EB, so no rate can
# run off the end and print a bare magnitude with no unit.
#
# The trailing newline is load-bearing: writeShellApplication sets
# `errexit`, and `read` reports failure at EOF without a line delimiter,
# so omitting it kills the module before it prints its first line.
scale() {
  awk -v b="$1" 'BEGIN {
    split("B KB MB GB TB PB EB", u)
    i = 1
    while (b >= 99.95 && i < 7) { b /= 1024; i++ }
    printf "%.1f\t%s\n", b, u[i]
  }'
}

# Always exactly 7 columns: 4 for the magnitude, one real space, 2 for the
# unit. BOTH fields are right-aligned, so the label grows leftward from a
# fixed right edge and the decimal point, the digits and the unit each
# hold their own column:
#
# - %4s right-aligns the magnitude, so "9.0" pads to " 9.0" and lines its
#   decimal point up under the one in "99.9". Padding on the left is what
#   the arrow needs: the digits stay flush against the gap after it
#   instead of drifting away from it when the value is short.
# - %2s right-aligns the unit so it ENDS at the same column every time:
#   "B" becomes " B" and lines up under the "B" of "KB".
#
# The gap between the two is a literal space rather than padding, so it
# survives however wide either field renders.
#
# Verified across 0 B .. 16 EB: every label is 7 characters.
pad() { printf '%4s %2s' "$1" "$2"; }

# nmcli -t does NOT escape colons inside values, so it is only safe on
# fields that cannot contain one. DEVICE, TYPE and STATE cannot; a
# connection name or an SSID can, which is why those are fetched with -g
# (which escapes them as "\:") and unescaped explicitly below.
unescape() { printf '%s' "${1//\\:/:}"; }

# First connected physical device wins. `device status` lists devices in
# NetworkManager's own priority order, so the first match is the link
# actually carrying traffic rather than whichever interface sorts first.
primary() {
  nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | awk -F: -v ex="$EXCLUDE" '
    $1 ~ ex           { next }
    $2 == "wifi-p2p"  { next }
    $3 != "connected" { next }
    { printf "%s\t%s\n", $1, $2; exit }
  '
}

devfield() {
  unescape "$(nmcli -g "$1" device show "$2" 2>/dev/null | head -n1)"
}

# SSID is requested LAST so the fields before it - none of which can
# contain a colon - can be split off positionally and everything
# remaining rejoined as the SSID, whatever it contains.
wifi_ap() {
  nmcli -g ACTIVE,SIGNAL,RATE,SSID device wifi list ifname "$1" --rescan no 2>/dev/null |
    awk -F: '
      $1 == "yes" {
        ssid = $4
        for (i = 5; i <= NF; i++) ssid = ssid ":" $i
        printf "%s\t%s\t%s\n", $2, $3, ssid
        exit
      }
    '
}

# Labels are padded to one width so every value starts in the same column.
row() { printf '%-10s %s\n' "$1:" "$2"; }

# The tooltip answers "what am I connected through" - the question the
# label cannot answer, since the label is already showing the rate. It
# deliberately does NOT repeat the two numbers.
conninfo() {
  local dev type name addr gw signal rate ssid out
  IFS=$'\t' read -r dev type < <(primary) || true

  if [ -z "${dev:-}" ]; then
    printf 'Disconnected'
    return
  fi

  name=$(devfield GENERAL.CONNECTION "$dev")
  addr=$(devfield IP4.ADDRESS "$dev")
  gw=$(devfield IP4.GATEWAY "$dev")

  out=""
  case "$type" in
    ethernet)
      out+="$(row Link 'Ethernet')"$'\n'
      [ -n "$name" ] && out+="$(row Profile "$name")"$'\n'
      ;;
    wifi)
      IFS=$'\t' read -r signal rate ssid < <(wifi_ap "$dev") || true
      # The SSID arrives colon-escaped, because it is the one field here
      # that can legitimately contain a colon and so had to be fetched
      # with -g. Unescaping is what turns "Cafe\:Free" back into
      # "Cafe:Free"; without it the backslash reaches the tooltip.
      ssid=$(unescape "${ssid:-}")
      out+="$(row Link 'Wi-Fi')"$'\n'
      out+="$(row Network "${ssid:-${name:-unknown}}")"$'\n'
      [ -n "${signal:-}" ] && out+="$(row Signal "$signal%")"$'\n'
      [ -n "${rate:-}" ] && out+="$(row Rate "$rate")"$'\n'
      ;;
    *)
      out+="$(row Link "$type")"$'\n'
      [ -n "$name" ] && out+="$(row Profile "$name")"$'\n'
      ;;
  esac

  out+="$(row Interface "$dev")"$'\n'
  [ -n "$addr" ] && out+="$(row IPv4 "$addr")"$'\n'
  [ -n "$gw" ] && out+="$(row Gateway "$gw")"

  printf '%s' "${out%$'\n'}"
}

# The link does not change every second, and each refresh costs four
# nmcli round trips, so it is re-read on a slower cadence than the rate
# and reused in between. Primed before the loop so the very first line
# already carries a populated tooltip.
TOOLTIP_EVERY=5
tip=$(conninfo)
ticks=0

read -r prx ptx < <(sample)
while true; do
  sleep "$INTERVAL"
  read -r crx ctx < <(sample)
  down=$(( (crx - prx) / INTERVAL ))
  up=$((   (ctx - ptx) / INTERVAL ))
  prx=$crx; ptx=$ctx

  ticks=$(( ticks + 1 ))
  if [ "$ticks" -ge "$TOOLTIP_EVERY" ]; then
    tip=$(conninfo)
    ticks=0
  fi

  IFS=$'\t' read -r dnum dunit < <(scale "$down")
  IFS=$'\t' read -r unum uunit < <(scale "$up")

  # jq builds the JSON so an SSID containing a quote, a backslash or a
  # newline cannot break the contract with waybar. It also encodes the
  # real newlines below, so the label and the tooltip are written here as
  # ordinary multi-line text rather than as hand-escaped "\n".
  jq -cn \
    --arg down "$(pad "$dnum" "$dunit")" \
    --arg up "$(pad "$unum" "$uunit")" \
    --arg tip "$tip" \
    '{
       text: "↓ \($down)\n↑ \($up)",
       tooltip: $tip,
       class: "netspeed"
     }'
done
