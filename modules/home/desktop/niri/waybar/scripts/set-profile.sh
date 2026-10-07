profile="$1"
if ! asusctl profile set "$profile"; then
  notify-send -a Waybar -u critical "Power profile" "Failed to set $profile"
  exit 1
fi
notify-send -a Waybar -i battery "Power profile" "$(asusctl profile get | head -n1)"
