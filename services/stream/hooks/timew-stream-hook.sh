#!/usr/bin/env bash
# services/stream/hooks/timew-stream-hook.sh — TASK-STRM-006
#
# SOURCED helper: emits stream events when timew start/stop succeed.
# Called from lib/shell-integration.sh timew() wrapper — NOT a standalone hook file.
#
# Contract:
#   - MUST produce object hashes identical to adapt_timew (sha256(start_str + '|' + json.dumps(tags))[:12])
#   - MUST fail soft: never break timew (return 0 on any error)
#   - SOURCED context: no set -euo pipefail, no exit
#
# Design: dev/tasks/cards/TASK-STRM-006.md

if [[ -n "${_WW_STREAM_TIMEW_HOOK_LOADED:-}" ]]; then
  return 0 2>/dev/null || true
fi
_WW_STREAM_TIMEW_HOOK_LOADED=1

# _stream_timew_obj_hash <start_str> <tags_json>
# Compute the 12-char sha256 hash identical to adapt_timew's h12(start, json.dumps(tags))
_stream_timew_obj_hash() {
  local start_str="${1:-}" tags_json="${2:-[]}"
  python3 -c "
import sys, hashlib, json
start = sys.argv[1]
tags = json.loads(sys.argv[2])
# adapt_timew does: h12(start, json.dumps(tags))
# h12 joins with '|' then sha256[:12]
payload = start + '|' + json.dumps(tags)
print(hashlib.sha256(payload.encode()).hexdigest()[:12])
" "$start_str" "$tags_json" 2>/dev/null || echo ""
}

# _stream_timew_first_project <tags_json>
# Mirrors adapt_timew: first tag that is NOT a UUID
_stream_timew_first_project() {
  local tags_json="${1:-[]}"
  python3 -c "
import sys, json, re
UUID_PAT = re.compile(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', re.I)
tags = json.loads(sys.argv[1])
for t in tags:
    t = t.strip('\"\\\"')
    if t and not UUID_PAT.match(t):
        print(t)
        sys.exit(0)
print('')
" "$tags_json" 2>/dev/null || echo ""
}

# _stream_timew_emit_start <timewarriordb> <profile>
#
# Called AFTER a successful `timew start`. Queries the active interval
# via `timew export :id 1` to get exact start timestamp and tags.
_stream_timew_emit_start() {
  local twdb="${1:-}" prof="${2:-}"
  local log="${WW_BASE:-$HOME/ww}/stream/stream.log"
  [[ -d "$(dirname "$log")" ]] || return 0

  # Query active interval
  local json
  if [[ -n "$twdb" ]]; then
    json="$(TIMEWARRIORDB="$twdb" command timew export :id 1 2>/dev/null)" || return 0
  else
    json="$(command timew export :id 1 2>/dev/null)" || return 0
  fi
  [[ -n "$json" ]] || return 0

  # Parse the interval: extract start and tags
  local parsed
  parsed="$(python3 -c "
import sys, json
data = json.loads(sys.argv[1])
if not data or not isinstance(data, list) or not data[0]:
    sys.exit(1)
interval = data[0]
start = interval.get('start', '')
tags = interval.get('tags', [])
print(start)
print(json.dumps(tags))
" "$json" 2>/dev/null)" || return 0

  local start_str tags_json
  start_str="$(echo "$parsed" | head -1)"
  tags_json="$(echo "$parsed" | tail -1)"
  [[ -n "$start_str" ]] || return 0

  # Compute object hash — MUST match adapt_timew exactly
  local obj
  obj="$(_stream_timew_obj_hash "$start_str" "$tags_json")" || return 0
  [[ -n "$obj" ]] || return 0

  # Compute ts from the start timestamp (same as adapt_timew's tw_ts)
  local ts
  ts="$(python3 -c "
import sys
from datetime import datetime, timezone
s = sys.argv[1].replace('Z','')
try:
    dt = datetime.strptime(s, '%Y%m%dT%H%M%S').replace(tzinfo=timezone.utc)
    print(int(dt.timestamp()))
except Exception:
    print(0)
" "$start_str" 2>/dev/null)" || return 0
  [[ "$ts" != "0" && -n "$ts" ]] || return 0

  # Build proj from tags
  local proj
  proj="$(_stream_timew_first_project "$tags_json")" || proj=""

  # Build ctx JSON — matches adapt_timew's output format
  local ctx
  ctx="$(python3 -c "
import sys, json
prof = sys.argv[1]
proj = sys.argv[2]
tags = json.loads(sys.argv[3])
d = {'src':'timew','prof':prof,'actor':'profile:'+prof,'proj':proj,'tags':tags}
print(json.dumps(d, separators=(',',':')))
" "$prof" "$proj" "$tags_json" 2>/dev/null)" || return 0

  # Append the event — 5-field frozen encoding
  printf '%s B start %s %s\n' "$ts" "$obj" "$ctx" >> "$log" 2>/dev/null || true
}

# _stream_timew_emit_stop <timewarriordb> <profile>
#
# Called AFTER a successful `timew stop`. Queries the most recently completed
# interval via `timew export :id 1` (which returns the last tracked interval).
_stream_timew_emit_stop() {
  local twdb="${1:-}" prof="${2:-}"
  local log="${WW_BASE:-$HOME/ww}/stream/stream.log"
  [[ -d "$(dirname "$log")" ]] || return 0

  # Query the most recently completed interval
  local json
  if [[ -n "$twdb" ]]; then
    json="$(TIMEWARRIORDB="$twdb" command timew export :id 1 2>/dev/null)" || return 0
  else
    json="$(command timew export :id 1 2>/dev/null)" || return 0
  fi
  [[ -n "$json" ]] || return 0

  # Parse: extract start, end, and tags
  local parsed
  parsed="$(python3 -c "
import sys, json
data = json.loads(sys.argv[1])
if not data or not isinstance(data, list) or not data[0]:
    sys.exit(1)
interval = data[0]
start = interval.get('start', '')
end = interval.get('end', '')
tags = interval.get('tags', [])
if not end:
    sys.exit(1)
print(start)
print(end)
print(json.dumps(tags))
" "$json" 2>/dev/null)" || return 0

  local start_str end_str tags_json
  start_str="$(echo "$parsed" | sed -n '1p')"
  end_str="$(echo "$parsed" | sed -n '2p')"
  tags_json="$(echo "$parsed" | sed -n '3p')"
  [[ -n "$start_str" && -n "$end_str" ]] || return 0

  # Object hash from START and tags (same interval identity as adapt_timew)
  local obj
  obj="$(_stream_timew_obj_hash "$start_str" "$tags_json")" || return 0
  [[ -n "$obj" ]] || return 0

  # ts from the END timestamp (adapt_timew: ts_end for the stop event)
  local ts
  ts="$(python3 -c "
import sys
from datetime import datetime, timezone
s = sys.argv[1].replace('Z','')
try:
    dt = datetime.strptime(s, '%Y%m%dT%H%M%S').replace(tzinfo=timezone.utc)
    print(int(dt.timestamp()))
except Exception:
    print(0)
" "$end_str" 2>/dev/null)" || return 0
  [[ "$ts" != "0" && -n "$ts" ]] || return 0

  # Build proj from tags
  local proj
  proj="$(_stream_timew_first_project "$tags_json")" || proj=""

  # Build ctx JSON
  local ctx
  ctx="$(python3 -c "
import sys, json
prof = sys.argv[1]
proj = sys.argv[2]
tags = json.loads(sys.argv[3])
d = {'src':'timew','prof':prof,'actor':'profile:'+prof,'proj':proj,'tags':tags}
print(json.dumps(d, separators=(',',':')))
" "$prof" "$proj" "$tags_json" 2>/dev/null)" || return 0

  # Append the event — 5-field frozen encoding
  printf '%s B stop %s %s\n' "$ts" "$obj" "$ctx" >> "$log" 2>/dev/null || true
}

# _stream_timew_hook_installed — check if timew hook sourcing is active
# Returns 0 if the timew() wrapper includes stream emit calls, 1 otherwise
_stream_timew_hook_installed() {
  # The hook is active if this file is sourced and _WW_STREAM_TIMEW_HOOK_LOADED is set
  [[ -n "${_WW_STREAM_TIMEW_HOOK_LOADED:-}" ]]
}
