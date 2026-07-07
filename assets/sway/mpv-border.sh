#!/usr/bin/env bash
killall -q mpv-border.sh 2>/dev/null
swaymsg -t subscribe -m '["window"]' | while read -r line; do
  if echo "$line" | jq -e '.container.app_id == "mpv"' > /dev/null 2>&1; then
    swaymsg '[app_id="mpv"] border pixel 2'
  fi
done
