#!/usr/bin/env bash
# services/stream/lenses/board.sh — TASK-STRM-004
#
# The board: who/what is currently punched in.
# Computes the OPEN SET — B start events with no matching B stop.
# READ-ONLY: never writes to the log.

lens_describe() { echo "the board — who/what is currently punched in"; }

lens_run() {
  local _py; _py="$(mktemp /tmp/wwlens_board_XXXXXX.py)"
  cat > "$_py" <<'PYEOF'
import sys, json, os, time
from datetime import datetime, timezone

# Environment filters (set by cmd_board wrapper)
actor_filter = os.environ.get("BOARD_ACTOR_FILTER", "")
proj_filter  = os.environ.get("BOARD_PROJ_FILTER", "")
stale_dur    = os.environ.get("BOARD_STALE_DUR", "")
out_format   = os.environ.get("BOARD_FORMAT", "text")

now = int(time.time())

# Parse stale threshold (seconds)
stale_threshold = 0
if stale_dur:
    try:
        stale_threshold = int(stale_dur)
    except ValueError:
        stale_threshold = 0

# Track open punches: obj -> {ts, actor, proj, tags}
starts = {}

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    parts = line.split(None, 4)
    if len(parts) < 4:
        continue
    ts_str, op, action, obj = parts[0], parts[1], parts[2], parts[3]
    if op != "B":
        continue
    try:
        ts = int(ts_str)
    except ValueError:
        continue
    ctx_raw = parts[4] if len(parts) > 4 else "{}"
    try:
        ctx = json.loads(ctx_raw)
        if not isinstance(ctx, dict):
            ctx = {}
    except Exception:
        ctx = {}

    # Resolve actor: ctx.actor or fallback to profile:<prof>
    actor = ctx.get("actor")
    if not actor:
        actor = "profile:" + (ctx.get("prof") or "default")

    proj = ctx.get("proj", "")
    tags = ctx.get("tags", [])

    if action == "start":
        starts[obj] = {"ts": ts, "actor": actor, "proj": proj, "tags": tags}
    elif action in ("stop", "end"):
        starts.pop(obj, None)

# The remaining starts ARE the open set
if not starts:
    print("Nobody is in.")
    sys.exit(0)

# Build rows
rows = []
for obj, info in starts.items():
    duration_s = now - info["ts"]
    is_stale = stale_threshold > 0 and duration_s > stale_threshold
    rows.append({
        "actor": info["actor"],
        "object": obj,
        "proj": info["proj"],
        "since": info["ts"],
        "duration_s": duration_s,
        "stale": is_stale,
        "tags": info["tags"],
    })

# Sort by duration descending (longest open first)
rows.sort(key=lambda r: r["duration_s"], reverse=True)

# Apply filters
if actor_filter:
    rows = [r for r in rows if r["actor"] == actor_filter]
if proj_filter:
    rows = [r for r in rows if r["proj"] == proj_filter]

if not rows:
    print("Nobody is in.")
    sys.exit(0)

# Output
if out_format == "json":
    out = []
    for r in rows:
        out.append({
            "actor": r["actor"],
            "object": r["object"],
            "proj": r["proj"],
            "since": r["since"],
            "duration_s": r["duration_s"],
            "stale": r["stale"],
        })
    print(json.dumps(out, separators=(",", ":")))
else:
    # Text table
    def fmt_dur(secs):
        h, remainder = divmod(secs, 3600)
        m, _ = divmod(remainder, 60)
        if h:
            return f"{h}h {m:02d}m"
        return f"{m}m"

    def fmt_since(ts):
        dt = datetime.fromtimestamp(ts, tz=timezone.utc)
        return dt.strftime("%H:%M")

    # Column headers
    hdr = f"{'ACTOR':<25} {'OBJECT':<20} {'PROJ':<12} {'IN SINCE':<12} {'DURATION':<12}"
    sep = "\u2500" * 80
    print(hdr)
    print(sep)
    for r in rows:
        stale_mark = "  \u26a0 stale" if r["stale"] else ""
        line = f"{r['actor']:<25} {r['object']:<20} {r['proj']:<12} {fmt_since(r['since']):<12} {fmt_dur(r['duration_s']):<12}{stale_mark}"
        print(line)
PYEOF
  cat | python3 "$_py"
  rm -f "$_py"
}
