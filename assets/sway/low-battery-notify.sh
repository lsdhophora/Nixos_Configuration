#!/usr/bin/env bash

bat=/sys/class/power_supply/BAT0
warned_15=0
warned_5=0

while true; do
  if [ -f "$bat/capacity" ] && [ -f "$bat/status" ]; then
    pct=$(cat "$bat/capacity")
    status=$(cat "$bat/status")

    if [ "$status" != "Discharging" ]; then
      warned_15=0
      warned_5=0
    else
      [ "$pct" -gt 15 ] && warned_15=0
      [ "$pct" -gt 5 ]  && warned_5=0
    fi

    if [ "$status" = "Discharging" ]; then
      if [ "$pct" -le 5 ] && [ "$warned_5" -eq 0 ]; then
        notify-send -u critical -h string:x-dunst-stack-tag:low-battery \
          "Battery Critical" "Battery at ${pct}% — plug in now"
        warned_5=1
        warned_15=1
      elif [ "$pct" -le 15 ] && [ "$warned_15" -eq 0 ]; then
        notify-send -u critical -h string:x-dunst-stack-tag:low-battery \
          "Battery Low" "Battery at ${pct}% — consider plugging in"
        warned_15=1
      fi
    fi
  fi

  sleep 60
done
