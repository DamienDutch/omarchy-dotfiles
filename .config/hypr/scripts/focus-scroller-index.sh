#!/usr/bin/env bash
set -euo pipefail

key="${1:-}"

case "$key" in
  1|2|3|4|5|6|7|8|9) n="$key" ;;
  0) n=10 ;;
  *) exit 1 ;;
esac

ws_id="$(hyprctl -j activeworkspace | jq -r '.id')"

addr="$(
  hyprctl -j clients | jq -r --argjson ws "$ws_id" --argjson n "$n" '
    map(
      select(
        .mapped == true and
        .hidden == false and
        .floating == false and
        .workspace.id == $ws
      )
    )
    | sort_by(.at[0], .at[1])
    | .[$n - 1].address // empty
  '
)"

[ -n "$addr" ] && hyprctl dispatch focuswindow "address:$addr"
