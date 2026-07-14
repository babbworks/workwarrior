#!/usr/bin/env bash

# Load the events a LENS should see.
#
# `H` (the legacy positional header) was already excluded here — the codebase long ago
# established the rule that THE LOG'S OWN METADATA IS NOT AN EVENT THE LENSES ANALYSE.
#
# TASK-STRM-001 extends the same rule to `S` (System: `schema`, `reset`), which is the same
# category. Without this, the schema marker would appear as ACTIVITY THAT NEVER HAPPENED:
# burroughs would print it, pacioli would count it, and felt/dey/cooper — which measure event
# DENSITY — would read a synthetic event as real work. Six of the eight lenses do not filter by
# op, so this must be done here, once, rather than in each lens.
#
# The events remain in the log. They are simply not work.
replay_load() {
  local from="${1:-0}" to="${2:-9999999999}"
  [[ -f "$STREAM_LOG" ]] || { echo "No stream log: $STREAM_LOG" >&2; return 1; }
  awk -v from="$from" -v to="$to" \
    '$1~/^[0-9]+$/ && $1>=from && $1<=to && $2!="H" && $2!="S"' "$STREAM_LOG"
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
