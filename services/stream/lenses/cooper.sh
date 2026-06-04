#!/usr/bin/env bash

lens_describe() { echo "Cooper field — geometric projection of Dey signal (polar clock or cartesian)"; }

lens_run() {
  local _py; _py="$(mktemp /tmp/wwlens_XXXXXX.py)"
  cat > "$_py" <<'PYEOF'
import sys, json, math
from datetime import datetime, timezone

# Read D op events (Dey samples) or fall back to all events
samples = []
all_events = []

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    parts = line.split(None, 4)
    if len(parts) < 4:
        continue
    ts_str, op = parts[0], parts[1]
    ctx = parts[4] if len(parts) > 4 else '{}'
    try:
        ts = int(ts_str)
    except ValueError:
        continue

    all_events.append(ts)

    if op != 'D':
        continue
    try:
        meta = json.loads(ctx)
    except Exception:
        meta = {}
    samples.append({
        'ts': ts,
        'i':  float(meta.get('intensity',     meta.get('i', 0))),
        's':  float(meta.get('stability',     meta.get('s', 0.5))),
        'f':  float(meta.get('fragmentation', meta.get('f', 0))),
    })

# Fallback: synthesize samples from all event timestamps
if not samples and all_events:
    all_events.sort()
    BUCKET = 300
    start = all_events[0]
    end   = all_events[-1]
    t = start - (start % BUCKET)
    while t <= end:
        bucket = [ts for ts in all_events if t <= ts < t + BUCKET]
        if bucket:
            cnt = len(bucket)
            norm_i = min(1.0, cnt / max(BUCKET / 10, 1))
            samples.append({'ts': t, 'i': norm_i, 's': 0.5, 'f': 0.1})
        t += BUCKET

samples.sort(key=lambda s: s['ts'])

if not samples:
    print("No signal data for Cooper projection.")
    sys.exit(0)

# --- Polar ASCII projection: time-of-day → angle, intensity → radius ---
# Grid dimensions
WIDTH  = 60
HEIGHT = 28
CX = WIDTH  // 2
CY = HEIGHT // 2
MAX_R  = min(CX, CY) - 2

DENSITY = ' ·░▒▓█'

grid = [[' '] * WIDTH for _ in range(HEIGHT)]

# Normalize intensity
max_i = max(s['i'] for s in samples) or 1.0

for s in samples:
    date = datetime.fromtimestamp(s['ts'], tz=timezone.utc)
    secs_in_day = date.hour * 3600 + date.minute * 60 + date.second
    angle = (secs_in_day / 86400.0) * 2 * math.pi - math.pi / 2  # 0=midnight at top

    r = (s['i'] / max_i) * MAX_R
    x = round(CX + r * math.cos(angle))
    y = round(CY + r * math.sin(angle))

    if 0 <= x < WIDTH and 0 <= y < HEIGHT:
        # Denser char for higher intensity
        char_idx = min(len(DENSITY) - 1, max(1, round((s['i'] / max_i) * (len(DENSITY) - 1))))
        cur = grid[y][x]
        if DENSITY.index(cur) < char_idx:
            grid[y][x] = DENSITY[char_idx]

# Draw center dot
grid[CY][CX] = '+'

# Cardinal markers
if CY - MAX_R - 1 >= 0:
    for cx2, ch in enumerate('12:00'):
        if 0 <= CX - 2 + cx2 < WIDTH:
            grid[CY - MAX_R - 1][CX - 2 + cx2] = ch
if CY + MAX_R + 1 < HEIGHT:
    for cx2, ch in enumerate('00:00'):
        if 0 <= CX - 2 + cx2 < WIDTH:
            grid[CY + MAX_R + 1][CX - 2 + cx2] = ch

print("Cooper Field  —  Polar Projection  (time-of-day → angle, intensity → radius)")
print()
for row in grid:
    print('  ' + ''.join(row))

print()
print(f"  06:00 ← left   right → 18:00   ·=low   █=peak")
print()

# Summary stats
avg_i = sum(s['i'] for s in samples) / len(samples)
avg_s = sum(s['s'] for s in samples) / len(samples)
peak  = max(s['i'] for s in samples)
# Find peak time-of-day
peak_s = max(samples, key=lambda s: s['i'])
peak_dt = datetime.fromtimestamp(peak_s['ts'], tz=timezone.utc).strftime('%H:%M')
first_dt = datetime.fromtimestamp(samples[0]['ts'],  tz=timezone.utc).strftime('%Y-%m-%d')
last_dt  = datetime.fromtimestamp(samples[-1]['ts'], tz=timezone.utc).strftime('%Y-%m-%d')

print(f"  Samples: {len(samples)}  |  Range: {first_dt} → {last_dt}")
print(f"  Avg intensity: {avg_i:.3f}  |  Peak: {peak:.3f} at {peak_dt}  |  Avg stability: {avg_s:.3f}")
PYEOF
  cat | python3 "$_py"
  rm -f "$_py"
}
