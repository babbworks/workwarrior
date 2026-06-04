#!/usr/bin/env bash

lens_describe() { echo "state transitions — F op code timeline per object"; }

lens_run() {
  local _py; _py="$(mktemp /tmp/wwlens_XXXXXX.py)"
  cat > "$_py" <<'PYEOF'
import sys, json
from datetime import datetime, timezone

events = []
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    parts = line.split(None, 4)
    if len(parts) < 4:
        continue
    ts_str, op, action, obj = parts[0], parts[1], parts[2], parts[3]
    ctx = parts[4] if len(parts) > 4 else '{}'
    if op != 'F':
        continue
    try:
        ts = int(ts_str)
    except ValueError:
        continue
    try:
        meta = json.loads(ctx)
    except Exception:
        meta = {}
    events.append({
        'ts': ts,
        'action': action,
        'object': obj,
        'proj': meta.get('proj', ''),
        'tags': meta.get('tags', []),
        'name': meta.get('name', ''),
    })

if not events:
    print("No F (state transition) events found in stream.")
    sys.exit(0)

events.sort(key=lambda e: e['ts'])

# Per-object transition sequences
graphs = {}
for e in events:
    obj = e['object']
    graphs.setdefault(obj, []).append(e)

# Summary table
print(f"{'TIME':<19}  {'ACTION':<12}  {'OBJECT':<36}  {'PROJECT':<16}  NAME")
print('─' * 100)
for e in events:
    dt = datetime.fromtimestamp(e['ts'], tz=timezone.utc).strftime('%Y-%m-%d %H:%M:%S')
    obj_short = e['object'][:36]
    proj = (e['proj'] or '')[:16]
    name = (e['name'] or '')[:30]
    print(f"{dt:<19}  {e['action']:<12}  {obj_short:<36}  {proj:<16}  {name}")

print()
print(f"Transitions: {len(events)}  |  Objects: {len(graphs)}  |  Actions: {', '.join(sorted(set(e['action'] for e in events)))}")
print()

# Per-object transition chains
if len(graphs) > 0:
    print("OBJECT TRANSITION CHAINS")
    print('─' * 70)
    for obj, evts in sorted(graphs.items()):
        chain = ' → '.join(e['action'] for e in evts)
        name = evts[0].get('name', '') or obj[:20]
        print(f"  {obj[:20]:<20}  {chain}")
        if name and name != obj[:20]:
            print(f"  {'':20}  ({name[:50]})")
PYEOF
  cat | python3 "$_py"
  rm -f "$_py"
}
