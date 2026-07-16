#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WW_BASE="${WW_BASE:-$HOME/ww}"

source "$WW_BASE/lib/core-utils.sh" 2>/dev/null || {
  log_error()   { echo "[error] $*" >&2; }
  log_info()    { echo "[info]  $*"; }
  log_success() { echo "[ok]    $*"; }
}

source "$SCRIPT_DIR/lib/replay.sh"
source "$SCRIPT_DIR/lib/lenses.sh"
source "$SCRIPT_DIR/lib/adapters.sh"
source "$SCRIPT_DIR/lib/codecs.sh"
source "$SCRIPT_DIR/lib/actor.sh"

# actor-registry lives in the top-level lib/; resolve relative to the repo root.
# WW_BASE is the runtime home (~/$USER/ww), but the library ships with the repo.
_ww_lib_dir="${WW_BASE}/lib"
[[ -f "${_ww_lib_dir}/actor-registry.sh" ]] || _ww_lib_dir="${SCRIPT_DIR}/../../lib"
source "${_ww_lib_dir}/actor-registry.sh"

STREAM_DIR="${WW_BASE}/stream"
STREAM_LOG="${STREAM_DIR}/stream.log"

# TASK-STRM-001. The schema version this build WRITES. It is NOT the authority on what a given
# log IS — that is read from the log itself (_stream_log_schema_version). A constant cannot know
# the version of a file written by some other build.
STREAM_SCHEMA_VERSION="v1"

# ── the schema version is an EVENT, not a header (stream-event-v1.md §6) ─────
#
# The log has no header line: a comment would be garbage to the positional parser, which splits
# every line into exactly 5 fields. So the version is stated as an ordinary `S` (System) event —
# the same mechanism cmd_reset already uses. It is a valid 5-field event, every existing lens
# handles it as routine, it is greppable and dated, and it lives IN THE LOG'S OWN HISTORY.
#
# In an append-only system, even the schema version is an append.
#
# ABSENCE OF AN `S schema` EVENT MEANS v0. (A v0 log may also carry a legacy `0 H v0 stream.log`
# header written by _ensure_stream_dir; that is corroborating evidence, not the authority.)

# What version is THIS log? Read it from the log. Never from the constant.
_stream_log_schema_version() {
  [[ -f "$STREAM_LOG" ]] || { printf 'v0\n'; return 0; }
  local v
  v="$(awk '$2 == "S" && $3 == "schema" { ver = $4 } END { if (ver != "") print ver }' \
       "$STREAM_LOG" 2>/dev/null)"
  printf '%s\n' "${v:-v0}"
}

# Stamp the log as v1, exactly once. Idempotent: never double-writes.
#
# MUST run before any v1-only ctx key (e.g. `actor`) can be emitted — because absence of the
# marker is what MEANS v0, a v1 key in an unmarked log would be undetectable.
_stream_ensure_schema_marker() {
  _ensure_stream_dir
  local current
  current="$(_stream_log_schema_version)"
  [[ "$current" == "$STREAM_SCHEMA_VERSION" ]] && return 0

  local ts; ts="$(date +%s)"
  printf '%s S schema %s {"schema":"%s","prev":"%s"}\n' \
    "$ts" "$STREAM_SCHEMA_VERSION" "$STREAM_SCHEMA_VERSION" "$current" >> "$STREAM_LOG"
}

show_help() {
  cat <<EOF
stream — Workwarrior Stream Service (WWSS)

Append-only temporal event log with pluggable lens projections.
Substrate: Pacioli (append-only) + Hollerith (positional encoding).

USAGE
  ww stream <subcommand> [options]

SUBCOMMANDS
  emit <op> <action> <object> [ctx]   Append one event to stream.log
  ingest [--source SOURCE] [--from DATE]
                                      Ingest from WW data sources
                                      SOURCE: tasks|timew|jrnl|ledger|all (default: all)
  view [--lens NAME] [--format FMT]   Project stream through a lens
  replay [--lens NAME] [--from DATE] [--to DATE]
                                      Alias for view with time filtering
  sessions [--gap SECS] [--from DATE] [--to DATE]
                                      Detect and display session boundaries
                                      GAP: inactivity gap in seconds (default: 300)
  lens list                           List available lenses
  hooks install [--profile NAME]      Install task hook scripts into profile
  hooks remove  [--profile NAME]      Remove task hook scripts
  hooks status                        Show hook installation status
  status                              Show log stats and active profile
  reset --confirm                     Truncate stream.log (destructive)

EVENT FORMAT (Hollerith positional encoding)
  <unix_ts> <OP> <action> <object> <ctx_json>
  OPs: T=Task F=Frick B=Bundy D=Dey H=Hollerith S=System A=Annotation

LENSES
  burroughs   Raw chronological event log
  bundy       Interval accumulation with ASCII timeline
  hollerith   Matrix grid: time-bucket rows × object columns
  pacioli     Running event balance per object (ledger view)
  frick       State transitions — F op code timeline per object
  felt        Activity density — event-count heat map across time buckets
  dey         Behavioral signal — intensity/stability/fragmentation time-series
  cooper      Cooper field — geometric polar projection of Dey signal

FORMATS
  text        Human-readable table (default)
  json        JSON array of event tuples
  ascii       ASCII visualization (lens-dependent)

EXAMPLES
  ww stream status
  ww stream emit F start abc123 '{"prof":"work"}'
  ww stream ingest --source tasks
  ww stream view --lens burroughs
  ww stream view --lens bundy --format ascii
  ww stream view --lens frick
  ww stream view --lens felt
  ww stream view --lens dey
  ww stream view --lens cooper
  ww stream sessions
  ww stream sessions --gap 600
  ww stream lens list
  ww stream hooks install
EOF
}

cmd_emit() {
  local actor_flag=""
  local args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --actor) actor_flag="$2"; shift 2 ;;
      *) args+=("$1"); shift ;;
    esac
  done
  set -- "${args[@]}"

  local op="${1:-}" action="${2:-}" obj="${3:-}" ctx="${4:-}"
  if [[ -z "$op" || -z "$action" || -z "$obj" ]]; then
    log_error "emit requires: <op> <action> <object> [ctx]"
    exit 1
  fi

  # Inject actor into ctx if provided
  if [[ -n "$actor_flag" ]]; then
    if ! actor_validate "$actor_flag"; then
      log_error "Invalid --actor ID: '$actor_flag'"
      exit 1
    fi
    ctx=$(echo "${ctx:-{}}" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except:
    d = {}
d['actor'] = sys.argv[1]
print(json.dumps(d, separators=(',',':')))
" "$actor_flag")
  fi

  # TASK-STRM-001: stamp the schema BEFORE the event, so a v1-only ctx key can never land in a
  # log that still reads as v0. Idempotent.
  _stream_ensure_schema_marker
  local ts; ts="$(date +%s)"
  # The 5-field positional encoding is FROZEN (stream-event-v1.md §1). Every consumer parses
  # split(None, 4), so ctx IS the rest of the line: a 6th field is impossible, and inserting one
  # before ctx silently misreads every event ever written. New dimensions go in ctx.
  printf '%s %s %s %s %s\n' "$ts" "$op" "$action" "$obj" "$ctx" >> "$STREAM_LOG"
  log_success "Event appended: $ts $op $action ${obj:0:12}…"
}

cmd_punch() {
  local direction="" actor="" object="" proj="" tags_arr=()
  local at_time="" reason="" by_actor=""
  # Parse: ww stream punch in|out --actor <id> --object <obj> [--proj P] [--tags t1 t2]
  #        [--at <time>] [--reason <text>] [--by <reconciler>]
  direction="${1:-}"; shift || true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --actor)  actor="$2"; shift 2 ;;
      --object) object="$2"; shift 2 ;;
      --proj)   proj="$2"; shift 2 ;;
      --at)     at_time="$2"; shift 2 ;;
      --reason) reason="$2"; shift 2 ;;
      --by)     by_actor="$2"; shift 2 ;;
      --tags)   shift; while [[ $# -gt 0 && "$1" != --* ]]; do tags_arr+=("$1"); shift; done ;;
      *) log_error "Unknown option: $1"; exit 1 ;;
    esac
  done

  # Validate
  [[ -z "$direction" ]] && { log_error "Usage: ww stream punch in|out --actor <id> --object <obj>"; exit 1; }
  [[ "$direction" != "in" && "$direction" != "out" ]] && { log_error "Direction must be 'in' or 'out'"; exit 1; }
  [[ -z "$actor" ]] && { log_error "--actor required"; exit 1; }
  [[ -z "$object" ]] && { log_error "--object required"; exit 1; }

  # --reason is only valid on punch out
  if [[ -n "$reason" && "$direction" == "in" ]]; then
    log_error "--reason is only valid on punch out (reconciled close)"
    exit 1
  fi

  # Validate actor ID format
  if ! actor_validate "$actor"; then
    log_error "Invalid actor ID: '$actor' (must be <kind>:<local-id>)"
    exit 1
  fi

  # Check actor exists in registry (warning if not in profile members, error if unknown)
  if ! actor_reg_exists "$actor"; then
    log_error "Unknown actor: '$actor' — not found in registry (config/actors.yaml)"
    exit 1
  fi

  # Map direction to action
  local action
  [[ "$direction" == "in" ]] && action="start" || action="stop"

  # Determine timestamps
  local ts now_ts
  now_ts="$(date +%s)"
  if [[ -n "$at_time" ]]; then
    # --at sets the asserted timestamp (field 1)
    if [[ "$at_time" =~ ^[0-9]+$ ]]; then
      ts="$at_time"
    else
      ts="$(_date_to_ts "$at_time")"
    fi
  else
    ts="$now_ts"
  fi

  # If reconciled close: check already-closed, build reconciled ctx
  if [[ "$direction" == "out" && -n "$reason" ]]; then
    # Resolve reconciler
    local reconciler="${by_actor:-profile:${WARRIOR_PROFILE:-default}}"

    # Check if already closed (object not in open set)
    if [[ -f "$STREAM_LOG" ]]; then
      local is_open
      is_open=$(awk -v obj="$object" '
        $2 == "B" && $3 == "start" && $4 == obj { open = 1 }
        $2 == "B" && ($3 == "stop" || $3 == "end") && $4 == obj { open = 0 }
        END { print open+0 }
      ' "$STREAM_LOG")
      if [[ "$is_open" -eq 0 ]]; then
        log_info "Already closed: $object (no-op)"
        return 0
      fi
    fi

    # Build ctx with reconciled key
    local tags_json="[]"
    if [[ ${#tags_arr[@]} -gt 0 ]]; then
      tags_json=$(printf '%s\n' "${tags_arr[@]}" | python3 -c "import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))")
    fi
    local ctx
    ctx=$(python3 -c "
import json, sys
d = {'actor': sys.argv[1], 'src': 'stream', 'prof': sys.argv[2]}
if sys.argv[3]: d['proj'] = sys.argv[3]
tags = json.loads(sys.argv[4])
if tags: d['tags'] = tags
d['reconciled'] = {
    'by': sys.argv[5],
    'at': int(sys.argv[6]),
    'reason': sys.argv[7]
}
print(json.dumps(d, separators=(',',':')))
" "$actor" "${WARRIOR_PROFILE:-}" "$proj" "$tags_json" "$reconciler" "$now_ts" "$reason")

    _stream_ensure_schema_marker
    printf '%s %s %s %s %s\n' "$ts" "B" "stop" "$object" "$ctx" >> "$STREAM_LOG"
    log_success "Reconciled close: $actor → $object (by $reconciler, reason: $reason)"
    return 0
  fi

  # Regular (non-reconciled) punch
  local ctx
  local tags_json="[]"
  if [[ ${#tags_arr[@]} -gt 0 ]]; then
    tags_json=$(printf '%s\n' "${tags_arr[@]}" | python3 -c "import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))")
  fi
  ctx=$(python3 -c "
import json, sys
d = {'actor': sys.argv[1], 'src': 'stream', 'prof': sys.argv[2]}
if sys.argv[3]: d['proj'] = sys.argv[3]
tags = json.loads(sys.argv[4])
if tags: d['tags'] = tags
print(json.dumps(d, separators=(',',':')))
" "$actor" "${WARRIOR_PROFILE:-}" "$proj" "$tags_json")

  # Emit via the existing path (handles schema marker, append, log)
  _stream_ensure_schema_marker
  printf '%s %s %s %s %s\n' "$ts" "B" "$action" "$object" "$ctx" >> "$STREAM_LOG"
  log_success "Punch $direction: $actor → $object"
}

cmd_reconcile() {
  # ww stream reconcile --stale <seconds> --reason <text> [--at <time>] [--confirm]
  # Without --confirm: DRY RUN only (print what would be closed)
  # With --confirm: actually append events
  local stale="" reason="" at_time="" confirm=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --stale)   stale="$2"; shift 2 ;;
      --reason)  reason="$2"; shift 2 ;;
      --at)      at_time="$2"; shift 2 ;;
      --confirm) confirm="1"; shift ;;
      *) log_error "Unknown option: $1"; exit 1 ;;
    esac
  done

  # Validate required args
  [[ -z "$stale" ]] && { log_error "--stale <seconds> required"; exit 1; }
  [[ -z "$reason" ]] && { log_error "--reason <text> required"; exit 1; }
  [[ ! "$stale" =~ ^[0-9]+$ ]] && { log_error "--stale must be a number (seconds)"; exit 1; }

  if [[ ! -f "$STREAM_LOG" ]]; then
    log_info "No stream log. Nothing to reconcile."
    return 0
  fi

  # Resolve reconciler
  local reconciler="profile:${WARRIOR_PROFILE:-default}"

  # Determine asserted timestamp (field 1)
  local now_ts asserted_ts
  now_ts="$(date +%s)"
  if [[ -n "$at_time" ]]; then
    if [[ "$at_time" =~ ^[0-9]+$ ]]; then
      asserted_ts="$at_time"
    else
      asserted_ts="$(_date_to_ts "$at_time")"
    fi
  else
    asserted_ts="$now_ts"
  fi

  # Get the open set and filter by stale threshold
  local _py_reconcile; _py_reconcile="$(mktemp /tmp/ww_reconcile_XXXXXX.py)"
  cat > "$_py_reconcile" <<'PYEOF'
import sys, json, time

stale_threshold = int(sys.argv[1])
now = int(time.time())

# Track open punches: obj -> {ts, actor, proj}
starts = {}

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    parts = line.split(None, 4)
    if len(parts) < 4:
        continue
    ts_str, op, action, obj = parts[0], parts[1], parts[2], parts[3]
    if op != "B":
        continue
    try:
        ts = int(ts_str)
    except ValueError:
        continue
    ctx_raw = parts[4] if len(parts) > 4 else "{}"
    try:
        ctx = json.loads(ctx_raw)
        if not isinstance(ctx, dict):
            ctx = {}
    except Exception:
        ctx = {}

    actor = ctx.get("actor", "")
    proj = ctx.get("proj", "")

    if action == "start":
        starts[obj] = {"ts": ts, "actor": actor, "proj": proj}
    elif action in ("stop", "end"):
        starts.pop(obj, None)

# Filter to stale entries
stale_entries = []
for obj, info in starts.items():
    duration_s = now - info["ts"]
    if duration_s > stale_threshold:
        stale_entries.append({
            "object": obj,
            "actor": info["actor"],
            "proj": info["proj"],
            "since": info["ts"],
            "duration_s": duration_s,
        })

# Sort by duration descending
stale_entries.sort(key=lambda r: r["duration_s"], reverse=True)

# Output as JSON (one entry per line for easy parsing)
print(json.dumps(stale_entries, separators=(",", ":")))
PYEOF

  local stale_json
  stale_json=$(replay_load | python3 "$_py_reconcile" "$stale")
  rm -f "$_py_reconcile"

  local count
  count=$(printf '%s' "$stale_json" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

  if [[ "$count" -eq 0 ]]; then
    log_info "No stale punches found (threshold: ${stale}s). Nothing to reconcile."
    return 0
  fi

  # Dry-run (default): just print what would be closed
  if [[ -z "$confirm" ]]; then
    echo "DRY RUN — would close $count stale punch(es):"
    printf '%s' "$stale_json" | python3 -c "
import sys, json
entries = json.load(sys.stdin)
for e in entries:
    h = e['duration_s'] // 3600
    m = (e['duration_s'] % 3600) // 60
    dur = f'{h}h {m:02d}m' if h else f'{m}m'
    print(f\"  {e['actor']:<25} {e['object']:<20} open {dur}\")
"
    echo ""
    echo "Run with --confirm to apply."
    return 0
  fi

  # Confirmed: emit one reconciled B stop event per stale entry
  _stream_ensure_schema_marker
  printf '%s' "$stale_json" | python3 -c "
import sys, json
entries = json.load(sys.stdin)
reconciler = sys.argv[1]
now_ts = int(sys.argv[2])
asserted_ts = sys.argv[3]
reason = sys.argv[4]
prof = sys.argv[5]
for e in entries:
    ctx = {
        'actor': e['actor'],
        'src': 'stream',
        'prof': prof,
        'reconciled': {
            'by': reconciler,
            'at': now_ts,
            'reason': reason
        }
    }
    if e.get('proj'):
        ctx['proj'] = e['proj']
    print(f\"{asserted_ts} B stop {e['object']} {json.dumps(ctx, separators=(',',':'))}\")
" "$reconciler" "$now_ts" "$asserted_ts" "$reason" "${WARRIOR_PROFILE:-}" >> "$STREAM_LOG"

  echo "$count punches closed by $reconciler for reason: $reason"
}

cmd_ingest() {
  # TASK-STRM-001: the other write path — stamp before ingesting (idempotent).
  _stream_ensure_schema_marker
  local source="all"
  local from_date=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source) source="$2"; shift 2 ;;
      --from)   from_date="$2"; shift 2 ;;
      *) log_error "Unknown option: $1"; exit 1 ;;
    esac
  done

  _ensure_stream_dir

  local before=0
  [[ -f "$STREAM_LOG" ]] && before=$(wc -l < "$STREAM_LOG" | tr -d ' ')

  case "$source" in
    tasks)  adapt_tasks  | _dedup_events "$STREAM_LOG" | _append_sorted ;;
    timew)  adapt_timew  | _dedup_events "$STREAM_LOG" | _append_sorted ;;
    jrnl)   adapt_jrnl   | _dedup_events "$STREAM_LOG" | _append_sorted ;;
    ledger) adapt_ledger | _dedup_events "$STREAM_LOG" | _append_sorted ;;
    all)
      { adapt_tasks; adapt_timew; adapt_jrnl; adapt_ledger; } \
        | _dedup_events "$STREAM_LOG" | _append_sorted
      ;;
    *) log_error "Unknown source: $source (tasks|timew|jrnl|ledger|all)"; exit 1 ;;
  esac

  local after=0
  [[ -f "$STREAM_LOG" ]] && after=$(wc -l < "$STREAM_LOG" | tr -d ' ')
  local added=$(( after - before ))
  log_success "Ingested $added new events from '$source' (total: $after)"
}

cmd_view() {
  local lens="burroughs"
  local format="text"
  local from_ts="0"
  local to_ts="9999999999"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --lens)   lens="$2";    shift 2 ;;
      --format) format="$2";  shift 2 ;;
      --from)   from_ts="$(_date_to_ts "$2")"; shift 2 ;;
      --to)     to_ts="$(_date_to_ts "$2")";   shift 2 ;;
      *) log_error "Unknown option: $1"; exit 1 ;;
    esac
  done

  if [[ ! -f "$STREAM_LOG" ]]; then
    log_error "No stream log found. Run: ww stream ingest"
    exit 1
  fi

  case "$format" in
    text|ascii) replay_load "$from_ts" "$to_ts" | replay_apply_lens "$lens" ;;
    json)       replay_load "$from_ts" "$to_ts" | codec_json ;;
    *) log_error "Unknown format: $format (text|json|ascii)"; exit 1 ;;
  esac
}

cmd_lens() {
  local sub="${1:-list}"
  case "$sub" in
    list) lens_list ;;
    *) log_error "Unknown lens subcommand: $sub"; exit 1 ;;
  esac
}

cmd_hooks() {
  local sub="${1:-status}"; shift || true
  local profile_name="${WARRIOR_PROFILE:-}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --profile) profile_name="$2"; shift 2 ;;
      *) log_error "Unknown option: $1"; exit 1 ;;
    esac
  done

  case "$sub" in
    install) _hooks_install "$profile_name" ;;
    remove)  _hooks_remove "$profile_name" ;;
    status)  _hooks_status ;;
    *) log_error "Unknown hooks subcommand: $sub (install|remove|status)"; exit 1 ;;
  esac
}

cmd_status() {
  _ensure_stream_dir
  local count=0 last_ts="" last_line=""
  if [[ -f "$STREAM_LOG" ]]; then
    count=$(wc -l < "$STREAM_LOG" | tr -d ' ')
    last_line=$(tail -1 "$STREAM_LOG" 2>/dev/null || true)
    last_ts=$(echo "$last_line" | awk '{print $1}')
  fi
  echo "Stream log:     ${STREAM_LOG}"
  echo "Events:         ${count}"
  if [[ -n "$last_ts" && "$last_ts" =~ ^[0-9]+$ ]]; then
    echo "Last event:     $(date -r "$last_ts" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$last_ts")"
    echo "Last entry:     $last_line"
  fi
  echo "Profile:        ${WARRIOR_PROFILE:-(none active)}"
  # TASK-STRM-001 criterion 4: report what THIS LOG is, not what this build writes. A constant
  # cannot know the version of a file written by another build. Absence of an `S schema` event
  # means v0.
  local log_ver; log_ver="$(_stream_log_schema_version)"
  echo "Schema:         ${log_ver}   (this build writes ${STREAM_SCHEMA_VERSION})"
}

cmd_reset() {
  local confirmed="${1:-}"
  if [[ "$confirmed" != "--confirm" ]]; then
    log_error "reset requires --confirm flag (destructive: truncates stream.log)"
    exit 1
  fi
  if [[ ! -f "$STREAM_LOG" ]]; then
    log_info "No stream.log to reset."
    return 0
  fi
  local ts; ts="$(date +%s)"
  printf '%s S reset stream.log {"reason":"user-reset"}\n' "$ts" >> "$STREAM_LOG"
  > "$STREAM_LOG"
  log_success "stream.log truncated (reset event recorded then cleared)"
}

cmd_sessions() {
  local gap_threshold=300
  local from_ts="0"
  local to_ts="9999999999"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --gap)  gap_threshold="$2"; shift 2 ;;
      --from) from_ts="$(_date_to_ts "$2")"; shift 2 ;;
      --to)   to_ts="$(_date_to_ts "$2")";   shift 2 ;;
      *) log_error "Unknown option: $1"; exit 1 ;;
    esac
  done

  if [[ ! -f "$STREAM_LOG" ]]; then
    log_error "No stream log found. Run: ww stream ingest"
    exit 1
  fi

  local _py; _py="$(mktemp /tmp/wwsess_XXXXXX.py)"
  cat > "$_py" <<'PYEOF'
import sys, time
from datetime import datetime, timezone

gap_threshold = int(sys.argv[1]) if len(sys.argv) > 1 else 300

timestamps = []
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    parts = line.split(None, 2)
    if not parts:
        continue
    try:
        timestamps.append(int(parts[0]))
    except ValueError:
        continue

if not timestamps:
    print("No events found in stream.")
    sys.exit(0)

timestamps.sort()

sessions = []
session_start = timestamps[0]
session_count = 1
last_ts = timestamps[0]

for ts in timestamps[1:]:
    gap = ts - last_ts
    if gap > gap_threshold:
        sessions.append({
            'start':    session_start,
            'end':      last_ts,
            'events':   session_count,
            'duration': last_ts - session_start,
            'open':     False,
        })
        session_start = ts
        session_count = 1
    else:
        session_count += 1
    last_ts = ts

now = int(time.time())
is_open = (now - last_ts) < gap_threshold
sessions.append({
    'start':    session_start,
    'end':      None if is_open else last_ts,
    'events':   session_count,
    'duration': (now if is_open else last_ts) - session_start,
    'open':     is_open,
})

def fmt_dur(secs):
    h, r = divmod(secs, 3600)
    m, s = divmod(r, 60)
    if h: return f"{h}h {m:02d}m"
    if m: return f"{m}m {s:02d}s"
    return f"{s}s"

def fmt_ts(ts):
    if ts is None: return '(open)             '
    return datetime.fromtimestamp(ts, tz=timezone.utc).strftime('%Y-%m-%d %H:%M:%S')

total_events   = sum(s['events']   for s in sessions)
total_duration = sum(s['duration'] for s in sessions)

print(f"Sessions detected: {len(sessions)}  (gap threshold: {gap_threshold}s)")
print(f"Total events: {total_events}  |  Active time: {fmt_dur(total_duration)}")
print()
print(f"  {'#':>3}  {'START':<19}  {'END':<19}  {'DURATION':>10}  {'EVENTS':>6}  STATUS")
print('  ' + '─' * 72)
for i, s in enumerate(sessions):
    status = 'open' if s['open'] else 'closed'
    print(f"  {i+1:>3}  {fmt_ts(s['start']):<19}  {fmt_ts(s['end']):<19}  {fmt_dur(s['duration']):>10}  {s['events']:>6}  {status}")
PYEOF
  replay_load "$from_ts" "$to_ts" | python3 "$_py" "$gap_threshold"
  rm -f "$_py"
}

_ensure_stream_dir() {
  if [[ ! -d "$STREAM_DIR" ]]; then
    mkdir -p "$STREAM_DIR"
    printf '0 H %s stream.log {"fields":"ts op action object ctx","encoding":"utf8"}\n' \
      "$STREAM_SCHEMA_VERSION" >> "$STREAM_LOG"
  fi
}

_append_sorted() {
  local tmp; tmp="$(mktemp)"
  cat >> "$tmp"
  if [[ -s "$tmp" ]]; then
    cat "$tmp" >> "$STREAM_LOG"
    sort -n -k1 -o "$STREAM_LOG" "$STREAM_LOG"
  fi
  rm -f "$tmp"
}

_date_to_ts() {
  local d="$1"
  if [[ "$d" =~ ^[0-9]+$ ]]; then
    echo "$d"
  else
    date -j -f "%Y-%m-%d" "$d" "+%s" 2>/dev/null \
      || date -d "$d" "+%s" 2>/dev/null \
      || echo "0"
  fi
}

_hooks_install() {
  local profile="${1:-}"
  local profiles_dir="${WW_BASE}/profiles"
  local targets=()
  if [[ -n "$profile" ]]; then
    targets=("${profiles_dir}/${profile}")
  else
    while IFS= read -r d; do targets+=("$d"); done \
      < <(find "$profiles_dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
  fi
  for pdir in "${targets[@]}"; do
    local hooks_dir="${pdir}/.task/hooks"
    [[ -d "$hooks_dir" ]] || continue
    _write_hook_onadd   "${hooks_dir}/on-add.stream-emit"
    _write_hook_onmodify "${hooks_dir}/on-modify.stream-emit"
    chmod +x "${hooks_dir}/on-add.stream-emit" "${hooks_dir}/on-modify.stream-emit"
    log_success "Hooks installed: $(basename "$pdir")"
  done
}

_hooks_remove() {
  local profile="${1:-}"
  local profiles_dir="${WW_BASE}/profiles"
  local targets=()
  if [[ -n "$profile" ]]; then
    targets=("${profiles_dir}/${profile}")
  else
    while IFS= read -r d; do targets+=("$d"); done \
      < <(find "$profiles_dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
  fi
  for pdir in "${targets[@]}"; do
    local hooks_dir="${pdir}/.task/hooks"
    rm -f "${hooks_dir}/on-add.stream-emit" "${hooks_dir}/on-modify.stream-emit"
    log_info "Hooks removed: $(basename "$pdir")"
  done
}

_hooks_status() {
  local profiles_dir="${WW_BASE}/profiles"
  printf "%-20s %-12s %-12s\n" "PROFILE" "TASK HOOKS" "TIMEW HOOK"
  printf "%s\n" "$(printf '%0.s─' {1..44})"
  while IFS= read -r pdir; do
    local name; name="$(basename "$pdir")"
    local hooks_dir="${pdir}/.task/hooks"
    local task_status="none" timew_status="none"
    if [[ -f "${hooks_dir}/on-add.stream-emit" ]]; then
      task_status="installed"
    fi
    # TASK-STRM-006: timew hook is active if the shell-integration.sh sources the hook helper
    local hook_helper="${SCRIPT_DIR}/hooks/timew-stream-hook.sh"
    if [[ -f "$hook_helper" ]]; then
      timew_status="active"
    fi
    printf "%-20s %-12s %-12s\n" "$name" "$task_status" "$timew_status"
  done < <(find "$profiles_dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)
}

_write_hook_onadd() {
  cat > "$1" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
ts=$(date +%s)
uuid=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('uuid',''))" 2>/dev/null || true)
proj=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('project',''))" 2>/dev/null || true)
tags=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('tags',[])))" 2>/dev/null || echo "[]")
desc=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('description','')[:60].replace('\"','\\\"'))" 2>/dev/null || true)
prof="${WARRIOR_PROFILE:-}"
log="${WW_BASE:-$HOME/ww}/stream/stream.log"
if [[ -d "$(dirname "$log")" && -n "$uuid" ]]; then
  c="{\"src\":\"task\",\"prof\":\"${prof}\",\"proj\":\"${proj}\",\"tags\":${tags},\"name\":\"${desc}\"}"
  printf '%s T add %s %s\n' "$ts" "$uuid" "$c" >> "$log" 2>/dev/null || true
fi
echo "$input"
HOOK
}

_write_hook_onmodify() {
  cat > "$1" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
IFS= read -r old
new=$(cat)
ts=$(date +%s)
uuid=$(echo "$new" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('uuid',''))" 2>/dev/null || true)
proj=$(echo "$new" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('project',''))" 2>/dev/null || true)
tags=$(echo "$new" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('tags',[])))" 2>/dev/null || echo "[]")
desc=$(echo "$new" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('description','')[:60].replace('\"','\\\"'))" 2>/dev/null || true)
status=$(echo "$new" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',''))" 2>/dev/null || true)
start=$(echo "$new" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('start',''))" 2>/dev/null || true)
prof="${WARRIOR_PROFILE:-}"
log="${WW_BASE:-$HOME/ww}/stream/stream.log"
if [[ -d "$(dirname "$log")" && -n "$uuid" ]]; then
  c="{\"src\":\"task\",\"prof\":\"${prof}\",\"proj\":\"${proj}\",\"tags\":${tags},\"name\":\"${desc}\"}"
  action="modify"
  op="T"
  case "$status" in
    completed) action="done" ;;
    deleted)   action="delete" ;;
  esac
  if [[ -n "$start" ]]; then
    op="F"; action="start"
  fi
  printf '%s %s %s %s %s\n' "$ts" "$op" "$action" "$uuid" "$c" >> "$log" 2>/dev/null || true
fi
echo "$new"
HOOK
}

cmd_board() {
  local actor_filter="" proj_filter="" stale_dur="" format="text"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --actor)  actor_filter="$2"; shift 2 ;;
      --proj)   proj_filter="$2"; shift 2 ;;
      --stale)  stale_dur="$2"; shift 2 ;;
      --format) format="$2"; shift 2 ;;
      *) log_error "Unknown option: $1"; exit 1 ;;
    esac
  done

  if [[ ! -f "$STREAM_LOG" ]]; then
    echo "Nobody is in. (No stream log found.)"
    exit 0
  fi

  # Feed the board lens with filter args passed as env vars.
  # Export so the second stage of the pipe (replay_apply_lens) inherits them.
  export BOARD_ACTOR_FILTER="$actor_filter"
  export BOARD_PROJ_FILTER="$proj_filter"
  export BOARD_STALE_DUR="$stale_dur"
  export BOARD_FORMAT="$format"
  replay_load | replay_apply_lens "board"
}

main() {
  local cmd="${1:-help}"
  shift || true
  case "$cmd" in
    emit)           cmd_emit "$@" ;;
    punch)          cmd_punch "$@" ;;
    reconcile)      cmd_reconcile "$@" ;;
    board)          cmd_board "$@" ;;
    ingest)         cmd_ingest "$@" ;;
    view|replay)    cmd_view "$@" ;;
    sessions)       cmd_sessions "$@" ;;
    lens)           cmd_lens "$@" ;;
    hooks)          cmd_hooks "$@" ;;
    status)         cmd_status ;;
    reset)          cmd_reset "$@" ;;
    help|-h|--help) show_help; exit 0 ;;
    *)
      echo "Unknown subcommand: $cmd" >&2
      show_help >&2
      exit 1
      ;;
  esac
}

main "$@"
