#!/usr/bin/env bash
# Layout composers — multi-panel terminal layouts.
# Source renderers.sh first if you need drawing primitives.

# ── Grid layout ──────────────────────────────────────────────────────────────

# viz_grid_panel TITLE CONTENT [WIDTH]
# Renders a single panel with a titled border. CONTENT is a string (may include newlines).
viz_grid_panel() {
  local title="$1"
  local content="$2"
  local width="${3:-$(tput cols 2>/dev/null || echo 80)}"

  local inner=$(( width - 4 ))
  [[ $inner -lt 10 ]] && inner=10

  # Top border with title
  local title_pad=$(( inner - ${#title} - 2 ))
  [[ $title_pad -lt 0 ]] && title_pad=0
  printf '┌─ %s %s┐\n' "$title" "$(printf '%*s' "$title_pad" '' | tr ' ' '─')"

  # Content lines
  while IFS= read -r line; do
    # Truncate/pad to inner width
    local trimmed="${line:0:$inner}"
    printf '│ %-*s │\n' "$inner" "$trimmed"
  done <<< "$content"

  # Bottom border
  printf '└%s┘\n' "$(printf '%*s' $(( inner + 2 )) '' | tr ' ' '─')"
}

# viz_grid COLUMNS PANELS...
# Renders PANELS in a grid with COLUMNS columns.
# Each panel is a "TITLE:CONTENT" string (base64-encoded content to handle newlines).
# Simpler alternative: just print panels vertically (terminal doesn't easily do columns).
# This implementation does vertical stacking with clear panel boundaries.
viz_grid_vertical() {
  local width="${VIZ_GRID_WIDTH:-$(tput cols 2>/dev/null || echo 80)}"
  # Each arg is "TITLE\tCONTENT"
  for panel in "$@"; do
    local title="${panel%%	*}"
    local content="${panel#*	}"
    viz_grid_panel "$title" "$content" "$width"
    echo ""
  done
}

# ── Timeline layout ───────────────────────────────────────────────────────────

# viz_timeline_bar TS_START TS_END TS_MIN TS_MAX LABEL [WIDTH]
# Renders a single timeline bar showing where [TS_START,TS_END] falls within [TS_MIN,TS_MAX].
viz_timeline_bar() {
  local ts_start="$1" ts_end="$2" ts_min="$3" ts_max="$4"
  local label="$5"
  local width="${6:-50}"

  python3 -c "
import sys
ts_start = int(sys.argv[1])
ts_end   = int(sys.argv[2])
ts_min   = int(sys.argv[3])
ts_max   = int(sys.argv[4])
label    = sys.argv[5]
width    = int(sys.argv[6])

span = ts_max - ts_min or 1
left  = max(0, min(width, round((ts_start - ts_min) / span * width)))
right = max(left, min(width, round((ts_end - ts_min) / span * width)))
bar   = ' ' * left + '█' * max(1, right - left) + ' ' * (width - right)
print(f'{label[:20]:<20}  [{bar}]')
" "$ts_start" "$ts_end" "$ts_min" "$ts_max" "$label" "$width"
}

# viz_field_render SAMPLES_JSON [WIDTH] [HEIGHT]
# Renders a polar field visualization from JSON array of {ts,i,s,f} objects.
# This is the terminal equivalent of the Cooper polar projection.
viz_field_render() {
  local samples_json="$1"
  local width="${2:-60}"
  local height="${3:-24}"

  python3 -c "
import sys, json, math

samples = json.loads(sys.argv[1])
width   = int(sys.argv[2])
height  = int(sys.argv[3])
cx = width  // 2
cy = height // 2
max_r = min(cx, cy) - 2

DENSITY = ' ·░▒▓█'
grid = [[' '] * width for _ in range(height)]

max_i = max((s.get('i', 0) for s in samples), default=1) or 1.0

for s in samples:
    from datetime import datetime, timezone
    dt = datetime.fromtimestamp(s['ts'], tz=timezone.utc)
    secs = dt.hour * 3600 + dt.minute * 60 + dt.second
    angle = (secs / 86400.0) * 2 * math.pi - math.pi / 2
    r = (s.get('i', 0) / max_i) * max_r
    x = round(cx + r * math.cos(angle))
    y = round(cy + r * math.sin(angle))
    if 0 <= x < width and 0 <= y < height:
        v = s.get('i', 0) / max_i
        idx = min(len(DENSITY)-1, max(1, round(v*(len(DENSITY)-1))))
        if DENSITY.index(grid[y][x]) < idx:
            grid[y][x] = DENSITY[idx]

grid[cy][cx] = '+'
for row in grid:
    print('  ' + ''.join(row))
" "$samples_json" "$width" "$height"
}
