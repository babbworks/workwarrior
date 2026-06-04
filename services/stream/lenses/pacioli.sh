#!/usr/bin/env bash

lens_describe() { echo "Pacioli ledger — running event balance per object (append-only record)"; }

lens_run() {
  local _py; _py="$(mktemp /tmp/wwlens_XXXXXX.py)"
  cat > "$_py" <<'PYEOF'
import sys, json
from datetime import datetime, timezone

CREDIT = {'add', 'start', 'done', 'write', 'post', 'track'}
DEBIT  = {'delete', 'stop', 'fail', 'modify'}

counts = {}
names  = {}
rows   = []

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    parts = line.split(None, 4)
    if len(parts) < 4:
        continue
    ts_str, op, action, obj = parts[0], parts[1], parts[2], parts[3]
    ctx = parts[4] if len(parts) > 4 else '{}'
    if not ts_str.isdigit():
        continue
    ts = int(ts_str)
    try:
        meta = json.loads(ctx)
    except Exception:
        meta = {}
    name = meta.get('name', '') or meta.get('proj', '') or obj[:12]
    names[obj] = name
    counts[obj] = counts.get(obj, 0) + 1
    side = '+' if action in CREDIT else ('-' if action in DEBIT else ' ')
    dt = datetime.fromtimestamp(ts, tz=timezone.utc).strftime('%Y-%m-%d %H:%M')
    rows.append((obj, dt, action, side, counts[obj], name))

if not rows:
    print("No events to display.")
    sys.exit(0)

print(f"{'OBJECT':<13}  {'TIME':<16}  {'ACTION':<8}  {'':1}  {'RUNNING':>7}  NAME")
print('─' * 72)
for obj, dt, action, side, count, name in rows:
    print(f"{obj[:12]:<13}  {dt:<16}  {action:<8}  {side}  {count:>7}  {name[:30]}")
print()
print(f"Total objects: {len(counts)}   Total events: {len(rows)}")
PYEOF
  cat | python3 "$_py"
  rm -f "$_py"
}
