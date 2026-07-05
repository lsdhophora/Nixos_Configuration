#!/usr/bin/env bash
if swaymsg -t get_tree | jq -e 'any(..; select(.app_id? == "alacritty-dropdown" and .visible?))' > /dev/null 2>&1; then
    swaymsg '[app_id="alacritty-dropdown"]' move scratchpad
elif swaymsg -t get_tree | jq -e 'any(..; .app_id? == "alacritty-dropdown")' > /dev/null 2>&1; then
    fs_id=$(swaymsg -t get_tree | jq '.. | select(.fullscreen_mode? == 1) | .id')
    [ -n "$fs_id" ] && swaymsg "[con_id=$fs_id]" fullscreen disable
    swaymsg '[app_id="alacritty-dropdown"]' scratchpad show
    swaymsg '[app_id="alacritty-dropdown"]' focus
    swaymsg '[app_id="alacritty-dropdown"]' border pixel 2
    swaymsg '[app_id="alacritty-dropdown"]' move position center
else
    alacritty --class alacritty-dropdown -e tmux new-session -A -s ScratchPad &
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        swaymsg -t get_tree | jq -e 'any(..; .app_id? == "alacritty-dropdown")' > /dev/null 2>&1 && break
        sleep 0.05
    done
    swaymsg fullscreen disable
    swaymsg '[app_id="alacritty-dropdown"]' focus
    swaymsg '[app_id="alacritty-dropdown"]' border pixel 2
    swaymsg '[app_id="alacritty-dropdown"]' move position center
fi