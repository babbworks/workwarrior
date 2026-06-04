#!/usr/bin/env bash

replay_load() {
  local from="${1:-0}" to="${2:-9999999999}"
  [[ -f "$STREAM_LOG" ]] || { echo "No stream log: $STREAM_LOG" >&2; return 1; }
  awk -v from="$from" -v to="$to" '$1~/^[0-9]+$/ && $1>=from && $1<=to && $2!="H"' "$STREAM_LOG"
}

replay_apply_lens() {
  local name="$1"
  local lens_file="${SCRIPT_DIR}/lenses/${name}.sh"
  if [[ ! -f "$lens_file" ]]; then
    echo "Lens not found: $name" >&2
    echo "Available: $(ls "${SCRIPT_DIR}/lenses/"*.sh 2>/dev/null | xargs -n1 basename | sed 's/\.sh//' | tr '\n' ' ')" >&2
    return 1
  fi
  source "$lens_file"
  lens_run
}
