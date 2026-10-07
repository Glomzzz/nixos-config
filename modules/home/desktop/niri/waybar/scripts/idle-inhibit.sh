unit="waybar-prevent-lock"
if systemctl --user --quiet is-active "$unit.service"; then
  systemctl --user stop "$unit.service"
  notify-send -a Waybar -i battery "Prevent lock" "Off - idle locking restored"
else
  systemd-run --user --unit="$unit" --description="Waybar prevent lock" \
    systemd-inhibit --what=idle --who=Waybar --why="Prevent lock" \
    sleep infinity
  notify-send -a Waybar -i battery "Prevent lock" "On - screen will not lock"
fi
