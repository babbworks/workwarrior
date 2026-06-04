#!/usr/bin/env bash

lens_list() {
  printf "%-14s %s\n" "LENS" "DESCRIPTION"
  printf "%s\n" "$(printf '%0.s─' {1..60})"
  for f in "${SCRIPT_DIR}/lenses/"*.sh; do
    [[ -f "$f" ]] || continue
    local name; name="$(basename "$f" .sh)"
    (
      source "$f" 2>/dev/null
      desc="$(lens_describe 2>/dev/null || echo '')"
      printf "%-14s %s\n" "$name" "$desc"
    )
  done
}
