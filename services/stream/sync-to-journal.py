#!/usr/bin/env python3
"""
sync-to-journal.py — Derive hledger journal from stream.log punch intervals.

Contract: dev/schemas/punch-posting-v1.md
Task:     TASK-LED-015

REGENERATE, never append. The output is a PURE FUNCTION of stream.log.
Running twice produces byte-identical output.
"""

import json
import os
import sys
from datetime import datetime, timezone

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

PRECISION = 2  # hours, from units.yaml h.precision


def load_actors_yaml(ww_base):
    """Load actors.yaml and return a dict of actor_id -> display name."""
    actors_path = os.path.join(ww_base, "config", "actors.yaml")
    if not os.path.isfile(actors_path):
        return {}
    try:
        import yaml
        with open(actors_path) as f:
            doc = yaml.safe_load(f)
        if not doc or not isinstance(doc.get("actors"), dict):
            return {}
        result = {}
        for actor_id, info in doc["actors"].items():
            if isinstance(info, dict) and info.get("display"):
                result[actor_id] = info["display"]
        return result
    except Exception:
        return {}


def resolve_actor_display(actor_id, actors_map):
    """Resolve display name for an actor. Falls back to actor_id."""
    return actors_map.get(actor_id, actor_id)


def resolve_actor(ctx):
    """Resolve actor from ctx: ctx.actor or 'profile:' + ctx.prof or 'profile:default'."""
    actor = ctx.get("actor")
    if actor:
        return actor
    prof = ctx.get("prof")
    if prof:
        return "profile:" + prof
    return "profile:default"


def resolve_target_account(ctx, obj):
    """Resolve target account: time:project:<proj> or time:unclassified:<object>."""
    proj = ctx.get("proj")
    if proj:
        return "time:project:" + proj
    return "time:unclassified:" + obj


def parse_stream_log(log_path):
    """Parse stream.log and return list of completed punch intervals.

    Each interval is a dict with:
      start_ts, end_ts, object, start_ctx, stop_ctx
    """
    if not os.path.isfile(log_path):
        return []

    # Collect B start/stop events keyed by (actor, object)
    # An actor can only have one open punch on an object at a time.
    # Match start/stop in order: first unmatched start gets matched by the next stop.
    starts = {}  # key: (actor, object) -> list of start events (FIFO)
    intervals = []

    with open(log_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = line.split(None, 4)
            if len(parts) < 4:
                continue
            ts_str, op, action, obj = parts[0], parts[1], parts[2], parts[3]
            if op != "B":
                continue
            if action not in ("start", "stop"):
                continue

            try:
                ts = int(ts_str)
            except ValueError:
                continue

            ctx_str = parts[4] if len(parts) > 4 else "{}"
            try:
                ctx = json.loads(ctx_str)
            except (json.JSONDecodeError, ValueError):
                ctx = {}

            actor = resolve_actor(ctx)
            key = (actor, obj)

            if action == "start":
                starts.setdefault(key, []).append({"ts": ts, "ctx": ctx})
            elif action == "stop":
                # Match with earliest unmatched start for this (actor, object)
                if key in starts and starts[key]:
                    start_event = starts[key].pop(0)
                    if not starts[key]:
                        del starts[key]
                    intervals.append({
                        "start_ts": start_event["ts"],
                        "end_ts": ts,
                        "object": obj,
                        "start_ctx": start_event["ctx"],
                        "stop_ctx": ctx,
                    })

    return intervals


def format_transaction(interval, actors_map):
    """Format a single interval as an hledger transaction per punch-posting-v1.md."""
    start_ts = interval["start_ts"]
    end_ts = interval["end_ts"]
    obj = interval["object"]
    # Use stop_ctx for reconciled info, start_ctx for actor/proj
    start_ctx = interval["start_ctx"]
    stop_ctx = interval["stop_ctx"]

    # Actor from start event (the one who punched in)
    actor_id = resolve_actor(start_ctx)

    # Duration
    duration_seconds = end_ts - start_ts
    duration_hours = round(duration_seconds / 3600, PRECISION)

    # Accounts
    target_account = resolve_target_account(start_ctx, obj)
    source_account = "actors:" + actor_id

    # Display name
    actor_display = resolve_actor_display(actor_id, actors_map)

    # Date from start_ts
    dt = datetime.fromtimestamp(start_ts, tz=timezone.utc)
    date_str = dt.strftime("%Y-%m-%d")

    # Object hash (use object directly as the identifier)
    obj_hash = obj

    # Reconciled?
    reconciled = stop_ctx.get("reconciled")

    # Build transaction lines
    lines = []

    # Description line
    desc = f"punch  {actor_display} -> {obj}"
    if reconciled:
        lines.append(f"{date_str} * {desc}  ; reconciled")
    else:
        lines.append(f"{date_str} * {desc}")

    # Metadata comments
    lines.append(f"    ; stream:obj={obj_hash}")
    lines.append(f"    ; stream:actor={actor_id}")
    lines.append(f"    ; stream:start={start_ts}")
    lines.append(f"    ; stream:end={end_ts}")

    # Reconciliation metadata
    if reconciled and isinstance(reconciled, dict):
        if reconciled.get("by"):
            lines.append(f"    ; reconciled:by={reconciled['by']}")
        if reconciled.get("at"):
            lines.append(f"    ; reconciled:at={reconciled['at']}")
        if reconciled.get("reason"):
            lines.append(f"    ; reconciled:reason={reconciled['reason']}")

    # Postings
    duration_str = f"{duration_hours:.{PRECISION}f}"
    lines.append(f"    {target_account}          {duration_str} h")
    lines.append(f"    {source_account}          -{duration_str} h")

    return "\n".join(lines)


def generate_journal(log_path, ww_base, generated_ts=None):
    """Generate the full journal content as a string."""
    actors_map = load_actors_yaml(ww_base)
    intervals = parse_stream_log(log_path)

    # Sort by start_ts (deterministic — stable sort preserves insertion order for ties)
    intervals.sort(key=lambda x: x["start_ts"])

    # Header
    if generated_ts is None:
        generated_ts = datetime.now(tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    header_lines = [
        "; GENERATED by ww ledger sync-stream — DO NOT EDIT",
        f"; Source: {log_path}",
        f"; Generated: {generated_ts}",
        "; Regenerate with: ww ledger sync-stream",
        "",
    ]

    # Transactions
    txn_blocks = []
    for interval in intervals:
        txn_blocks.append(format_transaction(interval, actors_map))

    content = "\n".join(header_lines)
    if txn_blocks:
        content += "\n".join(txn_blocks) + "\n"

    return content, len(intervals)


def main():
    import argparse

    parser = argparse.ArgumentParser(
        description="Derive hledger journal from stream.log punch intervals."
    )
    parser.add_argument("--stream-log", required=True, help="Path to stream.log")
    parser.add_argument("--ww-base", required=True, help="WW_BASE path")
    parser.add_argument("--output", help="Output file path (omit for stdout/dry-run)")
    parser.add_argument("--dry-run", action="store_true", help="Print to stdout, don't write")
    parser.add_argument(
        "--generated-ts",
        help="Override generated timestamp (for idempotent tests)",
    )

    args = parser.parse_args()

    content, count = generate_journal(
        args.stream_log, args.ww_base, generated_ts=args.generated_ts
    )

    if args.dry_run or not args.output:
        sys.stdout.write(content)
        # Print count to stderr so caller can parse it
        print(f"sync-stream: {count} transactions", file=sys.stderr)
    else:
        # Ensure directory exists
        os.makedirs(os.path.dirname(args.output), exist_ok=True)
        with open(args.output, "w") as f:
            f.write(content)
        print(f"sync-stream: {count} transactions written to {args.output}",
              file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
