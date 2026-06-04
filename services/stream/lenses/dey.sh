#!/usr/bin/env bash

lens_describe() { echo "Dey signal — behavioral intensity/stability/fragmentation time-series"; }

lens_run() {
  local _py; _py="$(mktemp /tmp/wwlens_XXXXXX.py)"
  cat > "$_py" <<'PYEOF'
import sys, json
from datetime import datetime, timezone

# Read D op events (periodic Dey samples emitted by stream service)
samples = []
all_events = []

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    parts = line.split(None, 4)
    if len(parts) < 4:
        continue
    ts_str, op, action, obj = parts[0], parts[1], parts[2], parts[3]
    ctx = parts[4] if len(parts) > 4 else '{}'
    try:
        ts = int(ts_str)
    except ValueError:
        continue

    all_events.append((ts, op))

    if op != 'D':
        continue
    try:
        meta = json.loads(ctx)
    except Exception:
        meta = {}

    samples.append({
        'ts':  ts,
        'i':   float(meta.get('intensity',    meta.get('i', 0))),
        's':   float(meta.get('stability',    meta.get('s', 0.5))),
        'f':   float(meta.get('fragmentation',meta.get('f', 0))),
    })

samples.sort(key=lambda s: s['ts'])

# --- If no D samples, compute approximate i/s/f from raw event density ---
if not samples and all_events:
    all_events.sort()
    start_ts = all_events[0][0]
    end_ts   = all_events[-1][0]
    BUCKET = 300  # 5-minute buckets
    t = start_ts - (start_ts % BUCKET)
    total = len(all_events)
    while t <= end_ts:
        bucket = [(ts, op) for ts, op in all_events if t <= ts < t + BUCKET]
        if bucket:
            cnt = len(bucket)
            norm_i = min(1.0, cnt / max(BUCKET / 10, 1))  # ~1 event/10s = full intensity
            # stability: high if few op types
            ops_seen = len(set(op for _, op in bucket))
            norm_s = max(0.0, 1.0 - (ops_seen - 1) * 0.2)
            # fragmentation: proxy via action diversity
            norm_f = min(1.0, (ops_seen - 1) * 0.15)
            samples.append({'ts': t, 'i': norm_i, 's': norm_s, 'f': norm_f})
        t += BUCKET

if not samples:
    print("No Dey signal data in stream. Run 'ww stream ingest' to populate.")
    print("(Dey samples are emitted periodically when the browser stream service is active.)")
    sys.exit(0)

# --- EMA smoothing ---
def ema(values, alpha=0.4):
    if not values: return []
    result = [values[0]]
    for v in values[1:]:
        result.append(alpha * v + (1 - alpha) * result[-1])
    return result

raw_i = [s['i'] for s in samples]
raw_s = [s['s'] for s in samples]
raw_f = [s['f'] for s in samples]
sm_i  = ema(raw_i, 0.4)
sm_s  = ema(raw_s, 0.2)
sm_f  = ema(raw_f, 0.2)

# --- ASCII chart ---
WIDTH  = 50
HEIGHT = 10

print(f"{'TIME':<19}  {'INT':>5}  {'STB':>5}  {'FRG':>5}  INTENSITY WAVEFORM")
print('─' * (19 + 5*3 + 6 + WIDTH + 4))

for idx, s in enumerate(samples):
    dt = datetime.fromtimestamp(s['ts'], tz=timezone.utc).strftime('%Y-%m-%d %H:%M:%S')
    i_val = sm_i[idx]
    s_val = sm_s[idx]
    f_val = sm_f[idx]
    filled = max(1, round(i_val * WIDTH)) if i_val > 0 else 0
    # Color via unicode block density
    char = '█' if i_val > 0.7 else ('▓' if i_val > 0.4 else ('▒' if i_val > 0.2 else '░'))
    bar = char * filled + '·' * (WIDTH - filled)
    print(f"{dt:<19}  {i_val:>5.3f}  {s_val:>5.3f}  {f_val:>5.3f}  [{bar}]")

print()
avg_i = sum(raw_i) / len(raw_i) if raw_i else 0
avg_s = sum(raw_s) / len(raw_s) if raw_s else 0
avg_f = sum(raw_f) / len(raw_f) if raw_f else 0
peak_i = max(raw_i) if raw_i else 0
print(f"Samples: {len(samples)}  |  Avg intensity: {avg_i:.3f}  |  Peak: {peak_i:.3f}  |  Avg stability: {avg_s:.3f}  |  Avg fragmentation: {avg_f:.3f}")
print()
print("Columns: INT=intensity  STB=stability  FRG=fragmentation  (EMA-smoothed, [0,1])")
PYEOF
  cat | python3 "$_py"
  rm -f "$_py"
}
