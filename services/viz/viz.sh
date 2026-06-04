#!/usr/bin/env bash
# Viz Service — Terminal visualization pipeline for Workwarrior stream data
# Usage: ww viz [subcommand] [options]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WW_BASE="${WW_BASE:-$HOME/ww}"

source "$WW_BASE/lib/core-utils.sh" 2>/dev/null || {
  log_error()   { echo "[error] $*" >&2; }
  log_info()    { echo "[info]  $*"; }
  log_success() { echo "[ok]    $*"; }
  log_warning() { echo "[warn]  $*"; }
}

source "$SCRIPT_DIR/lib/renderers.sh"
source "$SCRIPT_DIR/lib/layouts.sh"

STREAM_LOG="${WW_BASE}/stream/stream.log"
STREAM_SCRIPT="${WW_BASE}/services/stream/stream.sh"

# ── Helpers ───────────────────────────────────────────────────────────────────

_require_stream_log() {
  if [[ ! -f "$STREAM_LOG" ]]; then
    log_error "No stream log found at: $STREAM_LOG"
    log_info  "Run: ww stream ingest"
    exit 1
  fi
}

_stream_lens() {
  local lens="$1"; shift
  local from_ts="${1:-0}"
  local to_ts="${2:-9999999999}"
  local lens_file="${WW_BASE}/services/stream/lenses/${lens}.sh"
  if [[ ! -f "$lens_file" ]]; then
    log_error "Lens not found: $lens"
    exit 1
  fi
  source "$lens_file" 2>/dev/null
  awk -v f="$from_ts" -v t="$to_ts" \
    '$1~/^[0-9]+$/ && $1>=f && $1<=t && $2!="H"' "$STREAM_LOG" \
    | lens_run
}

_date_to_ts() {
  local d="$1"
  if [[ "$d" =~ ^[0-9]+$ ]]; then echo "$d"
  else
    date -j -f "%Y-%m-%d" "$d" "+%s" 2>/dev/null \
      || date -d "$d" "+%s" 2>/dev/null \
      || echo "0"
  fi
}

_stream_event_count() {
  [[ -f "$STREAM_LOG" ]] && grep -c '' "$STREAM_LOG" 2>/dev/null || echo 0
}

# ── Subcommands ───────────────────────────────────────────────────────────────

cmd_dashboard() {
  local from_ts="0"
  local to_ts="9999999999"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from) from_ts="$(_date_to_ts "$2")"; shift 2 ;;
      --to)   to_ts="$(_date_to_ts "$2")";   shift 2 ;;
      *) log_error "Unknown option: $1"; exit 1 ;;
    esac
  done

  _require_stream_log

  local cols; cols="$(tput cols 2>/dev/null || echo 80)"
  local events; events="$(_stream_event_count)"

  echo ""
  viz_header "Workwarrior Stream Dashboard" "$cols"
  viz_divider "$cols"
  echo "  Stream log:  $STREAM_LOG"
  echo "  Total events: $events"
  echo "  Profile:      ${WARRIOR_PROFILE:-(not set)}"
  echo ""

  # Mini-panel: Felt heatmap (compact, last 24h if no filter given)
  local felt_from="$from_ts"
  if [[ "$from_ts" == "0" ]]; then
    felt_from=$(( $(date +%s) - 86400 ))
  fi

  echo "── Activity Density (last 24h) ──────────────────────────────────────────"
  echo ""
  _stream_lens felt "$felt_from" "$to_ts" 2>/dev/null || echo "  (no events in range)"
  echo ""

  echo "── Sessions ─────────────────────────────────────────────────────────────"
  echo ""
  if [[ -f "$STREAM_SCRIPT" ]]; then
    bash "$STREAM_SCRIPT" sessions --from "$from_ts" --to "$to_ts" 2>/dev/null \
      || echo "  (no session data)"
  fi
  echo ""

  echo "── Dey Signal ───────────────────────────────────────────────────────────"
  echo ""
  _stream_lens dey "$from_ts" "$to_ts" 2>/dev/null || echo "  (no Dey samples)"
  echo ""
}

cmd_render() {
  local lens="${1:-burroughs}"; shift || true
  local from_ts="0"
  local to_ts="9999999999"
  local format="text"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from)   from_ts="$(_date_to_ts "$2")"; shift 2 ;;
      --to)     to_ts="$(_date_to_ts "$2")";   shift 2 ;;
      --format) format="$2"; shift 2 ;;
      *) log_error "Unknown option: $1"; exit 1 ;;
    esac
  done

  _require_stream_log
  _stream_lens "$lens" "$from_ts" "$to_ts"
}

cmd_sparkline() {
  # Read values from stdin or args, emit sparkline
  if [[ $# -gt 0 ]]; then
    viz_sparkline "$@"
  else
    local vals=()
    while IFS= read -r v; do vals+=("$v"); done
    viz_sparkline "${vals[@]}"
  fi
}

cmd_bar() {
  # Quick single bar: ww viz bar VALUE [LABEL] [WIDTH]
  local value="${1:-0}"
  local label="${2:-}"
  local width="${3:-40}"
  viz_gauge "$value" "$label" "$width"
}

cmd_bars() {
  # Read "LABEL VALUE" pairs from stdin, render bar chart
  viz_bars_from_stdin
}

cmd_grid() {
  # Show a 4-lens summary grid (burroughs, bundy, felt, dey)
  local from_ts="0"
  local to_ts="9999999999"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from) from_ts="$(_date_to_ts "$2")"; shift 2 ;;
      --to)   to_ts="$(_date_to_ts "$2")";   shift 2 ;;
      *) log_error "Unknown option: $1"; exit 1 ;;
    esac
  done

  _require_stream_log

  local cols; cols="$(tput cols 2>/dev/null || echo 80)"
  local LENSES=("burroughs" "bundy" "felt" "dey")

  for lens in "${LENSES[@]}"; do
    local title
    case "$lens" in
      burroughs) title="Burroughs — Raw Event Log" ;;
      bundy)     title="Bundy — Interval Accumulation" ;;
      felt)      title="Felt — Activity Density" ;;
      dey)       title="Dey — Behavioral Signal" ;;
    esac
    echo ""
    printf '┌─ %s ' "$title"
    printf '%*s' $(( cols - ${#title} - 4 )) '' | tr ' ' '─'
    printf '┐\n'

    # Run lens, indent content
    _stream_lens "$lens" "$from_ts" "$to_ts" 2>/dev/null \
      | while IFS= read -r line; do
          printf '│ %-*s │\n' $(( cols - 4 )) "${line:0:$(( cols - 4 ))}"
        done

    printf '└%*s┘\n' $(( cols - 2 )) '' | tr ' ' '─'
  done
  echo ""
}

cmd_field() {
  # Cooper polar field visualization
  local from_ts="0"
  local to_ts="9999999999"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from) from_ts="$(_date_to_ts "$2")"; shift 2 ;;
      --to)   to_ts="$(_date_to_ts "$2")";   shift 2 ;;
      *) log_error "Unknown option: $1"; exit 1 ;;
    esac
  done

  _require_stream_log
  echo ""
  _stream_lens cooper "$from_ts" "$to_ts"
  echo ""
}

cmd_timeline() {
  # Timeline view: bundy intervals as horizontal bars across a time axis
  local from_ts="0"
  local to_ts="9999999999"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from) from_ts="$(_date_to_ts "$2")"; shift 2 ;;
      --to)   to_ts="$(_date_to_ts "$2")";   shift 2 ;;
      *) log_error "Unknown option: $1"; exit 1 ;;
    esac
  done

  _require_stream_log

  # Use bundy lens (it already includes the ASCII timeline)
  echo ""
  _stream_lens bundy "$from_ts" "$to_ts"
  echo ""
}

cmd_lenses() {
  # List available lenses from stream service
  local lens_dir="${WW_BASE}/services/stream/lenses"
  printf "%-14s %s\n" "LENS" "DESCRIPTION"
  viz_divider 60
  for f in "${lens_dir}"/*.sh; do
    [[ -f "$f" ]] || continue
    local name; name="$(basename "$f" .sh)"
    local desc
    desc="$(bash -c "source '$f' 2>/dev/null; lens_describe 2>/dev/null || echo ''")"
    printf "%-14s %s\n" "$name" "$desc"
  done
}

show_help() {
  cat <<'EOF'
Viz Service — Terminal visualization pipeline for Workwarrior stream data

USAGE
  ww viz <subcommand> [options]

SUBCOMMANDS
  dashboard              Multi-panel session overview (felt + sessions + dey)
  render <lens>          Render a single stream lens
  grid                   Four-lens summary grid (burroughs/bundy/felt/dey)
  field                  Cooper polar field projection of Dey signal
  timeline               Bundy interval timeline
  sparkline [values...]  Render a sparkline from space-separated floats (or stdin)
  bar VALUE [LABEL] [W]  Render a single gauge bar for VALUE in [0,1]
  bars                   Render bar chart from "LABEL VALUE" pairs on stdin
  lenses                 List available stream lenses

OPTIONS
  --from DATE            Filter events from date (YYYY-MM-DD or unix timestamp)
  --to DATE              Filter events to date

EXAMPLES
  ww viz dashboard
  ww viz render burroughs
  ww viz render dey --from 2026-06-01
  ww viz grid
  ww viz field
  ww viz timeline
  ww viz sparkline 0.1 0.3 0.6 0.9 0.7 0.4
  echo -e "tasks 0.8\nledger 0.4\njrnl 0.6" | ww viz bars
  ww viz lenses

RENDERERS (library — source lib/renderers.sh to use in scripts)
  viz_bar VALUE [WIDTH] [CHAR] [LABEL]
  viz_sparkline VALUES...
  viz_block VALUE [LABEL]
  viz_bars_from_stdin
  viz_gauge VALUE [LABEL] [WIDTH]
  viz_divider [WIDTH]
  viz_header TEXT [WIDTH]

LAYOUTS (library — source lib/layouts.sh)
  viz_grid_panel TITLE CONTENT [WIDTH]
  viz_grid_vertical PANEL...
  viz_timeline_bar TS_START TS_END TS_MIN TS_MAX LABEL [WIDTH]
  viz_field_render SAMPLES_JSON [WIDTH] [HEIGHT]

LENSES (via stream service)
  burroughs   burroughs   felt        dey
  bundy       hollerith   frick       cooper      pacioli

EOF
}

main() {
  local cmd="${1:-help}"; shift || true
  case "$cmd" in
    dashboard)   cmd_dashboard "$@" ;;
    render)      cmd_render "$@" ;;
    grid)        cmd_grid "$@" ;;
    field)       cmd_field "$@" ;;
    timeline)    cmd_timeline "$@" ;;
    sparkline)   cmd_sparkline "$@" ;;
    bar)         cmd_bar "$@" ;;
    bars)        cmd_bars "$@" ;;
    lenses)      cmd_lenses "$@" ;;
    help|-h|--help) show_help; exit 0 ;;
    *)
      log_error "Unknown subcommand: $cmd"
      show_help >&2
      exit 1
      ;;
  esac
}

main "$@"
