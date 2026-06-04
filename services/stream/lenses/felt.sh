#!/usr/bin/env bash

lens_describe() { echo "activity density — event-count heat map across time buckets"; }

lens_run() {
  local _py; _py="$(mktemp /tmp/wwlens_XXXXXX.py)"
  cat > "$_py" <<'PYEOF'
import sys, json
from datetime import datetime, timezone

BUCKET_SIZE = 3600  # 1-hour default

events = []
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    parts = line.split(None, 4)
    if len(parts) < 3:
        continue
    ts_str, op = parts[0], parts[1]
    try:
        ts = int(ts_str)
    except ValueError:
        continue
    events.append((ts, op))

if not events:
    print("No events found in stream.")
    sys.exit(0)

events.sort()
start_ts = events[0][0]
end_ts   = events[-1][0]

# Build hourly buckets
buckets = []
t = start_ts - (start_ts % BUCKET_SIZE)  # align to hour boundary
while t <= end_ts:
    bucket_events = [e for e in events if t <= e[0] < t + BUCKET_SIZE]
    count = len(bucket_events)
    # Count by op type
    ops = {}
    for _, op in bucket_events:
        ops[op] = ops.get(op, 0) + 1
    buckets.append({'ts': t, 'count': count, 'ops': ops})
    t += BUCKET_SIZE

max_count = max((b['count'] for b in buckets), default=1)

# Heat chars: sparse to dense
HEAT  = ' ░▒▓█'
BAR_W = 40

print(f"{'TIME':<17}  {'COUNT':>5}  DENSITY")
print('─' * (17 + 2 + 5 + 2 + BAR_W + 12))

for b in buckets:
    if b['count'] == 0:
        continue
    dt = datetime.fromtimestamp(b['ts'], tz=timezone.utc).strftime('%Y-%m-%d %H:%M')
    norm = b['count'] / max_count
    # Fill bar with heat character based on density
    filled = max(1, round(norm * BAR_W))
    char_idx = min(len(HEAT) - 1, max(1, round(norm * (len(HEAT) - 1))))
    bar = HEAT[char_idx] * filled + ' ' * (BAR_W - filled)
    # Op breakdown compact
    op_str = ' '.join(f"{op}:{cnt}" for op, cnt in sorted(b['ops'].items()))
    print(f"{dt:<17}  {b['count']:>5}  [{bar}]  {op_str}")

print()
total = sum(b['count'] for b in buckets)
active = sum(1 for b in buckets if b['count'] > 0)
all_ops = {}
for b in buckets:
    for op, cnt in b['ops'].items():
        all_ops[op] = all_ops.get(op, 0) + cnt
op_summary = ' '.join(f"{op}:{cnt}" for op, cnt in sorted(all_ops.items()))
print(f"Total events: {total}  |  Active hours: {active} of {len(buckets)}  |  {op_summary}")
PYEOF
  cat | python3 "$_py"
  rm -f "$_py"
}
