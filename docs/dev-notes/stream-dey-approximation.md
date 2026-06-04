# Dey Lens — Approximation When No D-Op Samples Present

**Service:** `services/stream/lenses/dey.sh`  
**Also affects:** `services/viz/viz.sh` (dashboard, grid) when Dey data is missing

## What the code does

The Dey lens (`lenses/dey.sh`) has two execution paths:

1. **Primary path:** reads `D` op events directly from `stream.log`. These are
   periodic Dey samples emitted by the browser stream service
   (`services/stream/` in WebWarrior-copy) in the form:
   ```
   <ts> D sample session-YYYY-MM-DD {"intensity":0.7,"stability":0.5,"fragmentation":0.3}
   ```
   These contain measured intensity (i), stability (s), and fragmentation (f)
   values computed from a live event window using weighted source signals,
   EMA smoothing, and Shannon entropy.

2. **Fallback path (approximate):** when no D-op events exist — which is the case
   whenever the browser stream service has not been running — the lens synthesizes
   approximate i/s/f values from raw event density alone:
   - `i` (intensity) = `min(1, event_count / (bucket_seconds / 10))`
   - `s` (stability) = `max(0, 1 - (distinct_op_count - 1) * 0.2)`
   - `f` (fragmentation) = `min(1, (distinct_op_count - 1) * 0.15)`
   using 5-minute buckets.

## Why the approximation is coarse

The real Dey signal uses 11 weighted source signals (command_freq, task_transitions,
dwell_time, entropy, journal_freq, list_rate, idle_gap, session_length,
creation_rate, urgency_spread, nav_entropy), each contributing to i/s/f with
different weights, then applies EMA smoothing per dimension with separate window
sizes. The fallback uses only two signals (event count and op-type diversity) and
applies no smoothing.

This means:
- `i` in fallback mode reflects raw throughput, not weighted behavioral intensity
- `s` and `f` are proxies based on op diversity, not task-transition dwell time
  or project-switch entropy
- The output will look plausible as a trend indicator but should not be treated
  as equivalent to the measured signal

## When this matters

It matters if you are using the Dey or Cooper lens output to make decisions about
work patterns. If you have only ingested Taskwarrior/Timew/jrnl data via
`ww stream ingest`, you are always in fallback mode — the ingested events are
T, B, A, and T ops, never D ops.

D-op events are only written by the live browser stream service (WebWarrior-copy
/ the browser UI). They represent real-time sampling during an active browser
session.

## What to do

The fallback is intentional so the lens is not useless without the browser. If
you need the real Dey signal:

1. Use the browser UI (WebWarrior-copy or repos/ww browser service once it is
   fully wired) and keep it open during work sessions.
2. The browser stream service writes D-op events every `dey_interval` seconds
   (default 60) into `stream.log`. After a session, `ww stream ingest` will pick
   these up on the next run.

## Suppressing the fallback

The fallback is unconditional — there is no flag to disable it. If you want to
enforce the primary path only (fail rather than approximate), add a guard at the
top of the `# --- If no D samples` block in `dey.sh`:

```bash
# To enforce primary path only, replace the fallback block with:
if not samples:
    print("No Dey signal data. Browser stream service must be active to generate D-op samples.")
    sys.exit(1)
```
