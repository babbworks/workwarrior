#!/usr/bin/env bash

lens_describe() { echo "interval accumulation — duration totals with ASCII timeline"; }

lens_run() {
  local _py; _py="$(mktemp /tmp/wwlens_XXXXXX.py)"
  cat > "$_py" <<'PYEOF'
import sys, json, re
from datetime import datetime, timezone

starts = {}    # obj -> (ts, proj, tags)
intervals = [] # (obj, proj, tags, start_ts, end_ts, duration)

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    parts = line.split(None, 4)
    if len(parts) < 4:
        continue
    ts_str, op, action, obj = parts[0], parts[1], parts[2], parts[3]
    ctx = parts[4] if len(parts) > 4 else '{}'
    if op != 'B':
        continue
    try:
        ts = int(ts_str)
    except ValueError:
        continue
    try:
        meta = json.loads(ctx)
    except Exception:
        meta = {}
    proj = meta.get('proj', obj[:8])
    tags = meta.get('tags', [])
    if action == 'start':
        starts[obj] = (ts, proj, tags)
    elif action in ('stop', 'end') and obj in starts:
        start_ts, proj, tags = starts.pop(obj)
        dur = ts - start_ts
        if dur > 0:
            intervals.append((obj, proj, tags, start_ts, ts, dur))

if not intervals:
    print("No completed intervals found in stream.")
    sys.exit(0)

# Group by project
by_proj = {}
for obj, proj, tags, s, e, dur in intervals:
    key = proj or obj[:12]
    by_proj.setdefault(key, []).append((obj, s, e, dur))

# Table
print(f"{'PROJECT':<24}  {'INTERVALS':>9}  {'TOTAL':>10}  {'LAST ACTIVE':<19}")
print('─' * 70)
all_starts, all_ends = [], []

for proj, segs in sorted(by_proj.items()):
    total = sum(d for _, _, _, d in segs)
    h, m = divmod(total // 60, 60)
    last = max(e for _, _, e, _ in segs)
    dt = datetime.fromtimestamp(last, tz=timezone.utc).strftime('%Y-%m-%d %H:%M')
    print(f"{proj[:24]:<24}  {len(segs):>9}  {h:>4}h {m:02d}m  {dt:<19}")
    for _, s, e, _ in segs:
        all_starts.append(s)
        all_ends.append(e)

# ASCII timeline
if all_starts and all_ends:
    day_start = min(all_starts)
    day_end   = max(all_ends)
    span      = max(day_end - day_start, 1)
    width     = 60

    print()
    print("TIMELINE  (width proportional to wall-clock span)")
    print('─' * 70)
    for proj, segs in sorted(by_proj.items()):
        bar = [' '] * width
        for _, s, e, _ in segs:
            left  = int((s - day_start) / span * width)
            right = int((e - day_start) / span * width)
            for i in range(max(0, left), min(width, right + 1)):
                bar[i] = '█'
        total = sum(d for _, _, _, d in segs)
        h, m = divmod(total // 60, 60)
        print(f"{proj[:20]:<20}  [{''.join(bar)}]  {h}h {m:02d}m")

    start_dt = datetime.fromtimestamp(day_start, tz=timezone.utc).strftime('%H:%M')
    end_dt   = datetime.fromtimestamp(day_end,   tz=timezone.utc).strftime('%H:%M')
    pad = 22
    print(f"{'':>{pad}}{start_dt:<{width//2}}{end_dt:>{width//2}}")
PYEOF
  cat | python3 "$_py"
  rm -f "$_py"
}
