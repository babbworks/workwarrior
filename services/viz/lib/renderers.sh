#!/usr/bin/env bash
# Terminal rendering primitives — source this to use in any lens or script.

# ── Constants ────────────────────────────────────────────────────────────────

VIZ_BLOCKS=' ░▒▓█'        # density gradient (index 0=empty … 4=full)
VIZ_SPARK='▁▂▃▄▅▆▇█'     # sparkline chars (8 levels)
VIZ_BRAILLE=('⠀' '⠁' '⠃' '⠇' '⡇' '⣇' '⣧' '⣷' '⣿')  # braille density

# ── Bar renderer ─────────────────────────────────────────────────────────────

# viz_bar VALUE [WIDTH] [CHAR] [LABEL]
# Prints a single horizontal bar.
# VALUE: float in [0,1]; WIDTH: column width (default 40); CHAR: fill char (default █)
viz_bar() {
  local value="$1"
  local width="${2:-40}"
  local char="${3:-█}"
  local label="${4:-}"

  local filled
  filled=$(python3 -c "import sys; v=float(sys.argv[1]); w=int(sys.argv[2]); print(max(0,min(w,round(v*w))))" "$value" "$width" 2>/dev/null || echo 0)
  local empty=$(( width - filled ))

  if [[ -n "$label" ]]; then
    printf "%s [%s%s]\n" "$label" "$(printf "%${filled}s" | tr ' ' "$char")" "$(printf "%${empty}s")"
  else
    printf "[%s%s]\n" "$(printf "%${filled}s" | tr ' ' "$char")" "$(printf "%${empty}s")"
  fi
}

# ── Sparkline renderer ───────────────────────────────────────────────────────

# viz_sparkline VALUES...
# Renders a single-line sparkline from a space-separated list of floats.
# Input can be passed as arguments or on stdin (one per line).
viz_sparkline() {
  local values=("$@")
  if [[ ${#values[@]} -eq 0 ]]; then
    local v; while IFS= read -r v; do values+=("$v"); done
  fi
  python3 -c "
import sys
chars = '▁▂▃▄▅▆▇█'
vals = [float(v) for v in sys.argv[1:] if v]
if not vals:
    sys.exit(0)
mn, mx = min(vals), max(vals)
rng = mx - mn or 1.0
result = ''
for v in vals:
    idx = min(len(chars)-1, int((v - mn) / rng * (len(chars)-1)))
    result += chars[idx]
print(result)
" "${values[@]}"
}

# ── Block heatmap ────────────────────────────────────────────────────────────

# viz_block VALUE [LABEL]
# Renders a single density block character for VALUE in [0,1].
viz_block() {
  local value="$1"
  local label="${2:-}"
  python3 -c "
import sys
chars = ' ░▒▓█'
v = max(0.0, min(1.0, float(sys.argv[1])))
idx = min(len(chars)-1, int(v * (len(chars)-1)))
label = sys.argv[2] if len(sys.argv) > 2 else ''
if label:
    print(label + ' ' + chars[idx])
else:
    print(chars[idx])
" "$value" "$label"
}

# ── Multi-bar chart ──────────────────────────────────────────────────────────

# viz_bars_from_stdin
# Reads lines of "LABEL VALUE" from stdin, renders a bar chart.
# Optionally set VIZ_BAR_WIDTH (default 40) and VIZ_BAR_CHAR (default █).
viz_bars_from_stdin() {
  local width="${VIZ_BAR_WIDTH:-40}"
  local char="${VIZ_BAR_CHAR:-█}"
  python3 -c "
import sys
chars = sys.argv[1]
width = int(sys.argv[2])
rows = []
for line in sys.stdin:
    parts = line.strip().split(None, 1)
    if len(parts) == 2:
        try:
            rows.append((parts[0], float(parts[1])))
        except ValueError:
            pass
if not rows:
    sys.exit(0)
max_val = max(v for _, v in rows) or 1.0
label_w = max(len(r[0]) for r in rows)
for label, val in rows:
    filled = max(0, min(width, round(val / max_val * width)))
    empty  = width - filled
    bar    = chars * filled + ' ' * empty
    print(f'{label:{label_w}}  [{bar}]  {val:.3f}')
" "$char" "$width"
}

# ── Gauge ────────────────────────────────────────────────────────────────────

# viz_gauge VALUE [LABEL] [WIDTH]
# Like viz_bar but with percentage label appended.
viz_gauge() {
  local value="$1"
  local label="${2:-}"
  local width="${3:-30}"
  python3 -c "
import sys
v = max(0.0, min(1.0, float(sys.argv[1])))
label = sys.argv[2]
width = int(sys.argv[3])
filled = max(0, min(width, round(v * width)))
empty  = width - filled
bar  = '█' * filled + '░' * empty
pct  = f'{v*100:5.1f}%'
if label:
    print(f'{label} [{bar}] {pct}')
else:
    print(f'[{bar}] {pct}')
" "$value" "$label" "$width"
}

# ── Table helpers ─────────────────────────────────────────────────────────────

# viz_divider [WIDTH]
viz_divider() {
  local w="${1:-$(tput cols 2>/dev/null || echo 80)}"
  printf '%*s\n' "$w" '' | tr ' ' '─'
}

# viz_header TEXT [WIDTH]
viz_header() {
  local text="$1"
  local w="${2:-$(tput cols 2>/dev/null || echo 80)}"
  local pad=$(( (w - ${#text}) / 2 ))
  [[ $pad -lt 0 ]] && pad=0
  printf '%*s%s\n' "$pad" '' "$text"
}
