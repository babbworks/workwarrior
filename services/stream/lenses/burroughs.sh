#!/usr/bin/env bash

lens_describe() { echo "raw event log — chronological view of all events"; }

lens_run() {
  local cols; cols=$(tput cols 2>/dev/null || echo 100)
  local ctx_width=$(( cols - 74 ))
  [[ $ctx_width -lt 10 ]] && ctx_width=10

  printf "%-19s  %-2s  %-8s  %-36s  %s\n" "TIME" "OP" "ACTION" "OBJECT" "CONTEXT"
  printf '%*s\n' "$cols" '' | tr ' ' '─'

  while IFS=' ' read -r ts op action obj ctx; do
    [[ "$ts" =~ ^[0-9]+$ ]] || continue
    local dt
    dt="$(date -r "$ts" '+%Y-%m-%d %H:%M:%S' 2>/dev/null \
         || date -d "@$ts" '+%Y-%m-%d %H:%M:%S' 2>/dev/null \
         || echo "$ts")"
    local obj_short="${obj:0:36}"
    local ctx_short="${ctx:0:$ctx_width}"
    printf "%-19s  %-2s  %-8s  %-36s  %s\n" "$dt" "$op" "$action" "$obj_short" "$ctx_short"
  done
}
