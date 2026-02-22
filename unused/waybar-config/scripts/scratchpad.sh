#!/usr/bin/env bash

get_scratchpad_count() {
    swaymsg -t get_tree | jq 'recurse(.nodes[]) | first(select(.name=="__i3_scratch")) | .floating_nodes | length'
}

while true; do
    echo "$(get_scratchpad_count)"
    swaymsg -t subscribe -m '["window"]' | while read -r _; do
        echo "$(get_scratchpad_count)"
    done
done
