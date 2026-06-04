#!/usr/bin/env bash

lens_describe() { echo "Hollerith matrix — symbolic op-code grid: time-bucket rows × object columns"; }

lens_run() {
  local _py; _py="$(mktemp /tmp/wwlens_XXXXXX.py)"
  cat > "$_py" <<'PYEOF'
import sys, json
from datetime import datetime, timezone

BUCKET = 3600   # 1-hour buckets
OBJ_WIDTH = 9   # truncated object column width

events = []
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    parts = line.split(None, 4)
    if len(parts) < 4:
        continue
    ts_str, op, action, obj = parts[0], parts[1], parts[2], parts[3]
    if not ts_str.isdigit():
        continue
    ts = int(ts_str)
    events.append((ts, op, obj))

if not events:
    print("No events to display.")
    sys.exit(0)

# Collect unique objects, cap at 10 for readability
seen_objs = {}
for ts, op, obj in events:
    seen_objs.setdefault(obj, True)
objs = list(seen_objs.keys())[:10]
obj_idx = {o: i for i, o in enumerate(objs)}

# Build grid: bucket -> obj -> op (last wins per bucket)
grid = {}
for ts, op, obj in events:
    b = ts // BUCKET
    if obj not in obj_idx:
        continue
    grid.setdefault(b, {})[obj] = op

min_b = min(ts // BUCKET for ts, _, _ in events)
max_b = max(ts // BUCKET for ts, _, _ in events)

# Header
labels = [o[:OBJ_WIDTH-1].ljust(OBJ_WIDTH) for o in objs]
print(f"{'TIME':<17}  " + "  ".join(labels))
print('─' * (17 + 2 + (OBJ_WIDTH + 2) * len(objs)))

total_rows = 0
active_rows = 0
for b in range(min_b, max_b + 1):
    total_rows += 1
    row_objs = grid.get(b, {})
    if not row_objs:
        continue
    active_rows += 1
    dt = datetime.fromtimestamp(b * BUCKET, tz=timezone.utc).strftime('%Y-%m-%d %H:%M')
    cells = [row_objs.get(o, '.').center(OBJ_WIDTH) for o in objs]
    print(f"{dt:<17}  " + "  ".join(cells))

print()
print(f"Objects shown: {len(objs)} of {len(seen_objs)}  |  Active hours: {active_rows} of {total_rows}  |  OPs: T=Task F=Frick B=Bundy A=Annotation")
PYEOF
  cat | python3 "$_py"
  rm -f "$_py"
}
