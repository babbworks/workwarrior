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

STREAM_DIR="${WW_BASE}/stream"
STREAM_LOG="${STREAM_DIR}/stream.log"
STREAM_SCHEMA_VERSION="v0"

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
  local op="${1:-}" action="${2:-}" obj="${3:-}" ctx="${4:-}"
  if [[ -z "$op" || -z "$action" || -z "$obj" ]]; then
    log_error "emit requires: <op> <action> <object> [ctx]"
    exit 1
  fi
  _ensure_stream_dir
  local ts; ts="$(date +%s)"
  printf '%s %s %s %s %s\n' "$ts" "$op" "$action" "$obj" "$ctx" >> "$STREAM_LOG"
  log_success "Event appended: $ts $op $action ${obj:0:12}…"
}

cmd_ingest() {
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
  echo "Schema:         ${STREAM_SCHEMA_VERSION}"
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
  printf "%-20s %-12s\n" "PROFILE" "HOOKS"
  printf "%s\n" "$(printf '%0.s─' {1..32})"
  while IFS= read -r pdir; do
    local name; name="$(basename "$pdir")"
    local hooks_dir="${pdir}/.task/hooks"
    if [[ -f "${hooks_dir}/on-add.stream-emit" ]]; then
      printf "%-20s %-12s\n" "$name" "installed"
    else
      printf "%-20s %-12s\n" "$name" "none"
    fi
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
old=$(head -1)
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

main() {
  local cmd="${1:-help}"
  shift || true
  case "$cmd" in
    emit)           cmd_emit "$@" ;;
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
