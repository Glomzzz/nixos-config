set -o pipefail

fallback() {
  echo '{"text":"","tooltip":"weather unavailable","class":"unavailable"}'
  exit 0
}

# --fail turns HTTP >=400 into a non-zero exit (without it curl prints the
# error body and exits 0, which would reach jq as garbage). --show-error
# keeps the reason on stderr, where it lands in the waybar journal without
# ever contaminating the JSON on stdout.
raw=$(curl \
  --max-time 10 \
  --retry 2 \
  --silent \
  --fail \
  --show-error \
  'https://api.open-meteo.com/v1/forecast?latitude=3.139&longitude=101.6869&current=temperature_2m,weather_code&timezone=Asia%2FSingapore') || fallback

[ -n "$raw" ] || fallback

# -e makes jq exit non-zero on a null/false result, and the explicit type
# checks reject a well-formed response that is missing the fields (an API
# shape change would otherwise render as the string "null").
#
# `time` is checked the same way and in the same guard as the two numeric
# fields, not as a special case: it is interpolated into the tooltip's
# "Updated ..." line, so a null or empty value would render literally as
# "Updated null". Every field the output depends on shares one failure
# path, so there is exactly one way for this module to degrade.
fields=$(printf '%s' "$raw" | jq -er '
  .current as $c
  | if ($c.temperature_2m | type) != "number"
       or ($c.weather_code | type) != "number"
       or ($c.time | type) != "string"
       or ($c.time | length) == 0
    then error("open-meteo: current fields missing or of the wrong type")
    else "\($c.temperature_2m | round)\t\($c.weather_code)\t\($c.time)"
    end
') || fallback

IFS="$(printf '\t')" read -r temp code obstime <<< "$fields" || fallback
[ -n "$temp" ] && [ -n "$code" ] && [ -n "$obstime" ] || fallback

# WMO 4677 present-weather codes, as documented by Open-Meteo. Glyphs are
# material-design-icons from JetBrainsMono Nerd Font, each confirmed by
# NAME in the font's cmap rather than by guessing a codepoint: 󰖙 F0599
# md-weather_sunny, 󰖕 F0595 md-weather_partly_cloudy, 󰖐 F0590
# md-weather_cloudy, 󰖑 F0591 md-weather_fog, 󰼳 F0F33
# md-weather_partly_rainy, 󰙿 F067F md-weather_snowy_rainy, 󰖗 F0597
# md-weather_rainy, 󰖖 F0596 md-weather_pouring, 󰖘 F0598 md-weather_snowy,
# 󰖓 F0593 md-weather_lightning, 󰖒 F0592 md-weather_hail, 󰼯 F0F2F
# md-weather_cloudy_alert for the default.
#
# The default arm matters: WMO has codes this case does not enumerate, and
# an unmapped code must still render a glyph plus the number, so a gap is
# visible and diagnosable instead of showing a blank module.
case "$code" in
  0) icon="󰖙" desc="Clear sky" ;;
  1) icon="󰖕" desc="Mainly clear" ;;
  2) icon="󰖕" desc="Partly cloudy" ;;
  3) icon="󰖐" desc="Overcast" ;;
  45) icon="󰖑" desc="Fog" ;;
  48) icon="󰖑" desc="Depositing rime fog" ;;
  51) icon="󰼳" desc="Light drizzle" ;;
  53) icon="󰼳" desc="Moderate drizzle" ;;
  55) icon="󰼳" desc="Dense drizzle" ;;
  56) icon="󰙿" desc="Light freezing drizzle" ;;
  57) icon="󰙿" desc="Dense freezing drizzle" ;;
  61) icon="󰖗" desc="Slight rain" ;;
  63) icon="󰖗" desc="Moderate rain" ;;
  65) icon="󰖖" desc="Heavy rain" ;;
  66) icon="󰙿" desc="Light freezing rain" ;;
  67) icon="󰙿" desc="Heavy freezing rain" ;;
  71) icon="󰖘" desc="Slight snowfall" ;;
  73) icon="󰖘" desc="Moderate snowfall" ;;
  75) icon="󰖘" desc="Heavy snowfall" ;;
  77) icon="󰖘" desc="Snow grains" ;;
  80) icon="󰖗" desc="Slight rain showers" ;;
  81) icon="󰖗" desc="Moderate rain showers" ;;
  82) icon="󰖖" desc="Violent rain showers" ;;
  85) icon="󰖘" desc="Slight snow showers" ;;
  86) icon="󰖘" desc="Heavy snow showers" ;;
  95) icon="󰖓" desc="Thunderstorm" ;;
  96) icon="󰖒" desc="Thunderstorm with slight hail" ;;
  99) icon="󰖒" desc="Thunderstorm with heavy hail" ;;
  *) icon="󰼯" desc="Unmapped WMO code $code" ;;
esac

# Compact glyph + integer Celsius in `text`, mirroring KDE's
# showTemperatureInCompactMode; the fuller line goes in the tooltip.
#
# The tooltip's line breaks are joined BY jq rather than written as
# literal newlines in this string. A multi-line shell argument here
# would carry this Nix indented string's leading whitespace into the
# tooltip, and alejandra re-indents the whole block on every format
# run, so the rendered tooltip would silently shift with the formatter.
# jq -n with --arg also does all the JSON escaping, so the degree sign
# and any punctuation in $desc cannot break the contract.
jq -cn \
  --arg icon "$icon" \
  --arg desc "$desc" \
  --arg temp "$temp" \
  --arg code "$code" \
  --arg obstime "$obstime" \
  '{
     text: "\($icon) \($temp)°C",
     tooltip: ([
       "Kuala Lumpur: \($desc)",
       "\($temp)°C  (WMO \($code))",
       "Updated \($obstime)"
     ] | join("\n")),
     class: "weather"
   }' || fallback
