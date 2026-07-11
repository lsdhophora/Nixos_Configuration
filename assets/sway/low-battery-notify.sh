#!/usr/bin/env bash
bat=/sys/class/power_supply/BAT0

while true; do
  if [ -f "$bat/capacity" ]; then
    pct=$(cat "$bat/capacity")
    status=$(cat "$bat/status")

    if [ "$status" = "Discharging" ]; then
      if [ "$pct" -le 5 ]; then
        notify-send -u critical -h string:x-dunst-stack-tag:low-battery \
          "Battery Critical" "Battery at ${pct}% — click to dismiss (will re-alert)"
      elif [ "$pct" -le 15 ]; then
        notify-send -u critical -h string:x-dunst-stack-tag:low-battery \
          "Battery Low" "Battery at ${pct}% — click to dismiss"
      fi
    fi
  fi
  sleep 60
done
