# Plan: Workwarrior Stream Service (WWSS)

> Captured 2026-05-03. Review copy — canonical plan lives at `~/.claude/plans/in-a-recent-codex-synthetic-lemon.md`.

---

## Snapshot v1 — Initial architecture (pre-Hollerith/Pacioli harmonization)

**Captured 2026-05-03.** 8-layer pipeline only. Hollerith present as H opcode + matrix lens but not yet positioned as a substrate layer. Pacioli not yet included. Snapshot preserved here for reference; active plan below supersedes.

Pipeline at v1: Burroughs(event log) → Baldwin(state mutations) → Frick(transitions) → Bundy(intervals) → Grant(metrics) → Felt(density) → Dey(continuous signal) → Cooper(emergent field). Hollerith added as encoding-level lens. Event format: `<t> <op> <a> <b> <c>`.

---

## Context

The times-research corpus (13 documents) specifies WWSS as a "runtime kernel" for Workwarrior — an append-only event log that all other components derive their state from. The user wants a modular, multi-lens, codec-flexible service rather than type-rigid streaming. Ten inventors are harmonized into a 4-tier model: Pacioli + Hollerith as Tier 0 substrate (storage contract + encoding contract), then 8 computational layers above. The 8 names were given with no fixed ordering intention — positioning here is architectural judgment.

The full inventor set, harmonized (see Architecture section below):
- **Pacioli** — append-only ledger substrate (never delete, state = cumulative record)
- **Hollerith** — symbolic encoding substrate (compact, positional, machine-readable records)
- **Burroughs** — event log accumulation (additive recording machine)
- **Baldwin** — state mutation differencing (reversible calculation, delta tracking)
- **Frick** — discrete transition graph (instantaneous event markers, state changes)
- **Bundy** — interval segmentation (start/stop clock, bounded time units)
- **Grant** — derived metrics (aggregated measurement across intervals)
- **Felt** — activity density (compression/scoring of volume across buckets)
- **Dey** — continuous signal (analog dial, smoothed time-series)
- **Cooper** — emergent geometric field (projection of operational state into space)

Goal for this session: scaffold `services/stream/` with working ingest + replay skeleton, four lens implementations (Burroughs, Bundy, Hollerith, Pacioli), and a CLI surface that fits the existing WW service contract.

---

## Architecture Overview

### Full 10-Inventor Layer Model

```
┌─────────────────────────────────────────────────────────────────┐
│  TIER 0: SUBSTRATE  (invariants — not lenses, not negotiable)   │
│                                                                 │
│  Pacioli    append-only persistence; state = running record     │
│             never delete; replay reconstructs truth             │
│                                                                 │
│  Hollerith  symbolic encoding; fixed positional fields;         │
│             compact machine-readable records; sort by col 1     │
└─────────────────────────────────────────────────────────────────┘
                         │
                         ▼
Raw WW data sources (task, timew, jrnl, hledger)
         │
         ▼ adapters
   <unix_ts> <op> <a> <b> <c>     ← Hollerith encoding
         │
         ▼ Pacioli guarantee: append only
   stream.log  ← single source of truth
         │
         ▼ replay engine → lens pipeline
┌─────────────────────────────────────────────────────────────────┐
│  TIER A: EVENT LAYER                                            │
│  Burroughs  raw event log accumulation (additive recording)     │
│  Baldwin    state mutation diff (delta between versions)        │
│                                                                 │
│  TIER B: STRUCTURE                                              │
│  Frick      discrete transition graph (state change markers)    │
│  Bundy      interval segmentation (start/stop clock boundaries) │
│                                                                 │
│  TIER C: SIGNAL                                                 │
│  Grant      derived metrics (aggregated measurement)            │
│  Felt       activity density (volume → density score)           │
│  Dey        continuous signal (smoothed analog time-series)     │
│                                                                 │
│  TIER D: FIELD                                                  │
│  Cooper     emergent geometric field (state → spatial manifold) │
└─────────────────────────────────────────────────────────────────┘
         │
         ▼ output codecs
   JSON │ human-readable table │ ASCII viz
```

### Tier 0 Detail: Pacioli + Hollerith as Co-Substrate

**Pacioli** governs the storage contract:
- `stream.log` is an append-only file; no line is ever modified or deleted
- `stream reset` is a destructive override requiring explicit `--confirm`; it emits a `S reset` event before truncating so the act of reset is itself recorded
- All derived state (intervals, metrics, signals, fields) is reconstructed from the log on demand — never persisted as truth
- Pacioli lens (`pacioli.sh`): ledger-style view showing running balance of events per object (credits/debits of time and attention)

**Hollerith** governs the encoding contract:
- Five positional columns: `ts op a b c` — no named fields in the file, positions ARE the schema
- `op` is always a single uppercase letter (the punched-card compact code)
- `ts` is Unix timestamp integer — primary sort key, enables `sort -n -k1` as the only required processing primitive
- `c` field (occurrence) is optional minified JSON — no spaces between tokens
- `H` events at log head record the schema version; downstream tooling checks the `H` header before parsing
- Hollerith lens (`hollerith.sh`): matrix view (time-bucket rows × object columns × op-code cells)

### Hollerith Encoding Layer (Tier 0 Co-Substrate)

Hollerith is the **primary ordering and encoding mechanism for event lines**. Every line in `stream.log` is a Hollerith record: positionally fixed fields, symbolically compact, machine-readable without a schema file. The five-column format is not arbitrary — it is the Hollerith principle applied to temporal data. Paired with Pacioli (also Tier 0), these two substrate invariants are enforced before any lens or adapter runs.

```
<unix_ts> <op> <a> <b> <c>
col 1     col2  col3 col4 col5(optional)
```

Hollerith properties that must be preserved:
- Column positions are fixed-semantic (ts=ordering key, op=type discriminator, a=action, b=object, c=occurrence)
- `op` is a single uppercase letter — compact symbolic code (Hollerith card punch analogy)
- Lines are sortable by `sort -n` on col 1 alone — time-first ordering is primary
- No embedded newlines; `c` field is minified JSON (no spaces unless quoted)
- Each line is self-contained and decodable without context from adjacent lines

The **Hollerith lens** (`hollerith.sh`) renders a matrix/grid view: rows = time buckets, columns = object identifiers, cells = op codes. This is the encoding-level visualization — shows the symbolic structure of the stream itself rather than derived meaning.

```
           task-abc  task-def  interval-1  journal
08:00        T         .          B           .
09:00        F         T          .           .
10:00        .         F          B           A
11:00        D         D          .           .
```

### Event Format (canonical, v0)

```
<unix_ts> <op> <a> <b> <c>
```

| op | Name       | Meaning |
|----|------------|---------|
| T  | Task       | task lifecycle event (add/modify/done/delete) |
| F  | Frick      | state transition marker (start/stop/context switch) |
| B  | Bundy      | interval boundary (clock-in / clock-out) |
| D  | Dey        | signal sample (quality / energy / score) |
| H  | Hollerith  | encoding-level marker (schema version, field mapping event) |
| S  | System     | system/meta event (sync, replay, agent handoff) |
| A  | Annotation | annotation or journal entry attached to object |

`H` events appear at stream.log header (first line) and on schema migrations:
```
0 H v0 stream.log {"fields":"ts op a b c","encoding":"utf8"}
```

TAOO classification embedded in fields:
- `a` = Action (what happened — verb)
- `b` = Object (uuid or identifier)
- `c` = Occurrence metadata (profile, context, tags — compact JSON fragment)

---

## File Structure

```
services/stream/
  stream.sh              # entry point — WW service contract
  lib/
    adapters.sh          # ingest: task/timew/jrnl/ledger → canonical events
    replay.sh            # replay engine: filter log → event lines
    lenses.sh            # lens registry + dispatcher
    codecs.sh            # output codecs: json / text / ascii
    taoo.sh              # TAOO classification helpers
  lenses/
    burroughs.sh         # raw log view (MVP)
    bundy.sh             # interval accumulation (MVP)
    hollerith.sh         # encoding matrix/grid view (MVP)
    pacioli.sh           # ledger-style running balance view (MVP)
    frick.sh             # state transitions (follow-on)
    baldwin.sh           # state mutation diff (follow-on)
    grant.sh             # derived metrics (follow-on)
    felt.sh              # activity density (follow-on)
    dey.sh               # continuous signal (follow-on)
    cooper.sh            # geometric field ASCII (follow-on)
```

Storage (created at runtime, not in git):
```
$WW_BASE/stream/
  stream.log             # append-only event log
  .cache/                # derived layer caches (invalidated on replay)
```

---

## Critical Files to Create

### `services/stream/stream.sh` — entry point

Pattern: exactly like `services/warrior/warrior.sh`.

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WW_BASE="${WW_BASE:-$HOME/ww}"
source "$WW_BASE/lib/core-utils.sh" 2>/dev/null || {
  log_error() { echo "[error] $*" >&2; }
  log_info()  { echo "[info]  $*"; }
  log_success(){ echo "[ok]    $*"; }
}
STREAM_DIR="$WW_BASE/stream"
STREAM_LOG="$STREAM_DIR/stream.log"
```

Subcommands:
```
stream emit <op> <a> <b> [c]          append one event
stream ingest [--from DATE] [--source tasks|timew|jrnl|ledger|all]
stream replay [--lens NAME] [--from DATE] [--to DATE]
stream view   [--lens NAME] [--format json|text|ascii]   (alias: replay)
stream lens   list                     list available lenses
stream status                          log size, last event, profile
stream reset  --confirm                truncate log
```

Help/exit pattern:
- `-h|--help|help` → `show_help` then `exit 0`
- Unknown subcommand → stderr + `show_help` + `exit 1`
- Missing required arg → `log_error` + `exit 1`

### Standard Occurrence Field (`c`) — Tag and Project Flow

Every stream event's `c` field is a **minified JSON object** with a fixed schema. All adapters must produce this structure so lenses can filter by project and tags uniformly regardless of source.

```
{"src":"<adapter>","prof":"<profile>","proj":"<primary_project>","tags":["t1","t2"],"name":"<human_label>"}
```

| Key    | Required | Meaning |
|--------|----------|---------|
| `src`  | yes      | `"task"` \| `"timew"` \| `"jrnl"` \| `"ledger"` |
| `prof` | yes      | WW profile name (`$WARRIOR_PROFILE`) |
| `proj` | if present | Primary project — single string, `""` if none |
| `tags` | yes      | All tags/labels from source, may be `[]` |
| `name` | if present | Human-readable label (task description, jrnl title, ledger description) |

No spaces between JSON tokens in `c`. `stream.log` must remain sortable by col 1 (`sort -n`) — no bare newlines in `c`.

---

### Timew and Stream: Additive Relationship + Real-Time Emission

**Timew remains the authoritative time-tracking backend.** Users continue running `timew start <tags>` / `timew stop` directly. Stream is an additional unified lens — does not replace timew, jrnl, hledger, or taskwarrior. `configure-times.sh`, `ww time`, and the browser time panel continue to use timew directly.

**Real-time emission is in-scope for v1** — simpler than it sounds because the existing shell wrappers already intercept all calls.

#### Path 1: Shell wrapper injection (timew, jrnl, ledger)

`lib/shell-integration.sh` already wraps all three: `timew()` (line 765), `j()` (line 575), `l()` (line 663). After each successful write, a single append fires:

```bash
_stream_emit() {
  local op="$1" action="$2" obj="$3" c="$4"
  local log="${WW_BASE:-$HOME/ww}/stream/stream.log"
  [[ -d "$(dirname "$log")" ]] || return 0  # silent no-op if stream not installed
  printf '%s %s %s %s %s\n' "$(date +%s)" "$op" "$action" "$obj" "$c" >> "$log" 2>/dev/null || true
}
```

`_stream_emit` is a **silent no-op when stream is not installed** — safe to ship in shell-integration.sh for all WW installs.

Mutating actions intercepted:
- timew: `start`, `stop`, `track`, `delete`, `modify` → B events
- jrnl: any write call (not bare `j`, not read-only flags) → A events
- ledger: `add`, `import` → T events

#### Path 2: TaskWarrior hook scripts (task)

WW already creates `.task/hooks/` per profile (`lib/profile-manager.sh` lines 134, 188). Stream installs two scripts there:

```
profiles/<name>/.task/hooks/
  on-add.stream-emit       # stdin: new task JSON → emits T event
  on-modify.stream-emit    # stdin: old+new task JSON → emits T or F event
```

Managed via:
```
stream hooks install [--profile NAME]
stream hooks remove  [--profile NAME]
stream hooks status
```

#### Batch ingest — still needed

`stream ingest` covers: historical data predating stream installation, recovery from log loss, and any direct tool invocations outside WW shell wrappers. The two paths are complementary.

---

### `services/stream/lib/adapters.sh`

Functions: `adapt_tasks()`, `adapt_timew()`, `adapt_jrnl()`, `adapt_ledger()`

Each reads WW data via profile env vars, transforms to `<unix_ts> <op> <a> <b> <c>` lines with standardized `c` field, deduplicates before appending.

**Task adapter** (`adapt_tasks`):
- `task export` JSON already has `project`, `tags`, `description`, `uuid`, `entry`, `status`, `start`
- One T event per task; one F event if `start` present
- `proj` = `project` field; `tags` = `tags` array; `name` = first 60 chars of `description`
```
<entry_ts> T add <uuid>   {"src":"task","prof":"work","proj":"alpha","tags":["next","home"],"name":"Fix the login bug"}
<start_ts> F start <uuid> {"src":"task","prof":"work","proj":"alpha","tags":["next","home"],"name":"Fix the login bug"}
```

**Timew adapter** (`adapt_timew`):
- `TIMEWARRIORDB="$TIMEWARRIORDB" timew export` — same invocation as `lib/export-utils.sh` line 244
- Each interval JSON: `{"id":N,"start":"20260503T090000Z","end":"...","tags":["alpha","task-uuid","work"]}`
- One B start event, one B stop event per closed interval (skip open intervals — no `end` field)
- Object = sha256(start+tags)[0:12]; `proj` = first non-UUID tag; `tags` = full tags array
```
<start_ts> B start <hash12> {"src":"timew","prof":"work","proj":"alpha","tags":["alpha","work","abc-uuid"]}
<end_ts>   B stop  <hash12> {"src":"timew","prof":"work","proj":"alpha","tags":["alpha","work","abc-uuid"]}
```

**Jrnl adapter** (`adapt_jrnl`):
- `jrnl --format json` → `{"entries":[{"date":"...","title":"...","body":"...","tags":["@tag1","#tag2"]}]}`
- One A event per entry; ts = unix(date); object = sha256(date+title)[0:12]
- jrnl native tags: `@word` = project/person, `#word` = topic — strip prefix, carry in `tags` array
- `proj` = first `@mention` tag if present (jrnl convention); `name` = title
- Fallback to plain-text parsing if `--format json` unavailable: `YYYY-MM-DD HH:MM Title\nbody`, extract `@`/`#` from body
```
<entry_ts> A write <hash12> {"src":"jrnl","prof":"work","proj":"alpha","tags":["alpha","standup"],"name":"Morning standup"}
```

**Ledger adapter** (`adapt_ledger`):
- `hledger -f <file> print -O json` — same invocation as `lib/export-utils.sh` line 522
- hledger tags live in transaction comments: `; project:alpha, client:acme` → key:value pairs
- Account hierarchy carries structure: `expenses:work:software` → segments are implicit tags
- One T event per **posting** (not per transaction): ts = unix(date); object = sha256(date+desc+acct)[0:12]
- `proj` = `;project:` comment tag if present, else second account segment; `tags` = all `;tag:value` keys + account path segments
- Add `"ledger":"<filename>"` to `c` to indicate which .journal file the event came from
```
<tx_ts> T post <hash12> {"src":"ledger","prof":"work","proj":"alpha","tags":["alpha","software","expenses"],"name":"Monthly sub","ledger":"main"}
```

**Dedup helper:**
```bash
_dedup_events() {
  local log="$1"
  [[ -f "$log" ]] || { cat; return 0; }
  # Dedup on ts+op+a+b (cols 1-4); c-field changes alone do not create new events
  awk 'NR==FNR{seen[$1" "$2" "$3" "$4]=1;next} !seen[$1" "$2" "$3" "$4]' "$log" -
}
```

### `services/stream/lib/replay.sh`

```bash
replay_load() {
  # replay_load [from_ts] [to_ts] — filter stream.log, output events to stdout
  local from="${1:-0}" to="${2:-9999999999}"
  [[ -f "$STREAM_LOG" ]] || { log_error "No stream log at $STREAM_LOG"; return 1; }
  awk -v from="$from" -v to="$to" '$1>=from && $1<=to' "$STREAM_LOG"
}

replay_apply_lens() {
  # replay_apply_lens <lens_name> — pipe stdin events through lens
  local name="$1"
  local lens_file="$SCRIPT_DIR/lenses/${name}.sh"
  [[ -f "$lens_file" ]] || { log_error "Lens not found: $name"; return 1; }
  source "$lens_file"
  lens_run
}
```

### `services/stream/lib/lenses.sh`

```bash
lens_list() {
  for f in "$SCRIPT_DIR/lenses/"*.sh; do
    local name; name="$(basename "$f" .sh)"
    source "$f" 2>/dev/null
    printf "  %-12s %s\n" "$name" "$(lens_describe 2>/dev/null || echo '')"
  done
}

lens_dispatch() {
  local name="$1"; shift
  replay_apply_lens "$name"
}
```

### `services/stream/lenses/burroughs.sh` — MVP lens 1

Raw log view, human-readable formatting.

```bash
lens_describe() { echo "raw event log — chronological view of all events"; }

lens_run() {
  printf "%-20s %-4s %-8s %-36s %s\n" "TIME" "OP" "ACTION" "OBJECT" "CONTEXT"
  printf "%s\n" "$(printf '%0.s─' {1..80})"
  while IFS=' ' read -r ts op a b c; do
    local dt; dt="$(date -r "$ts" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "$ts")"
    printf "%-20s %-4s %-8s %-36s %s\n" "$dt" "$op" "$a" "${b:0:36}" "${c:-}"
  done
}
```

### `services/stream/lenses/bundy.sh` — MVP lens 2

Interval accumulation from B events.

ASCII bar output format:
```
project-a  [████████░░░░░░░░░░░░]  2h 15m
project-b  [░░░░░███████████░░░░]  4h 00m
           00:00                  23:59
```

### `services/stream/lenses/hollerith.sh` — MVP lens 3

Matrix/grid view: rows = time buckets (1-hour default), columns = distinct object identifiers, cells = op codes.

Output example:
```
TIME          task-abc   task-def   int-1     journal
2026-05-03    T          .          B         .
2026-05-03    F          T          .         .
2026-05-03    .          F          B         A
```

Column width auto-truncates object UUIDs to 8 chars for readability.

### `services/stream/lenses/pacioli.sh` — MVP lens 4

Ledger-style running balance. Each object gets a running account showing cumulative event count, honoring append-only guarantee by making it visible.

Output:
```
OBJECT                                TIME                  ACTION    RUNNING
────────────────────────────────────────────────────────────────────────────────
abc123-uuid-...                       2026-05-03 09:00      add       1
abc123-uuid-...                       2026-05-03 09:15      start     2
abc123-uuid-...                       2026-05-03 11:00      done      3
def456-uuid-...                       2026-05-03 10:00      add       1
```

### `services/stream/lib/codecs.sh`

```bash
codec_json()  { python3 -c "import sys,json; lines=sys.stdin.read().splitlines(); print(json.dumps([l.split(None,4) for l in lines if l]))"; }
codec_text()  { cat; }
codec_ascii() { cat; }
```

### `services/stream/lib/taoo.sh`

```bash
taoo_classify() {
  local ts="$1" op="$2" a="$3" b="$4" c="$5"
  printf "T=%s\tA=%s\tO=%s\tOcc=%s\n" "$ts" "$a" "$b" "$c"
}

taoo_filter() {
  local pattern="$1"
  awk -v p="$pattern" '$3 ~ p'
}
```

---

## How `bin/ww` Routes to `stream.sh`

Check `bin/ww` before implementing. If explicit case dispatch: add `stream) "$WW_BASE/services/stream/stream.sh" "$@" ;;`. If auto-discovery via glob: no change needed.

---

## Implementation Sequence

**Phase 1: Core log + batch ingest**
1. Storage init + `stream emit` + `stream status`
2. Task adapter → `stream ingest --source tasks`
3. `replay_load` + Burroughs lens → `stream view --lens burroughs`
4. Bundy lens + ASCII bars → `stream view --lens bundy`
5. Hollerith matrix lens → `stream view --lens hollerith`
6. Pacioli ledger lens → `stream view --lens pacioli`
7. Lens registry → `stream lens list`
8. Timew + jrnl + ledger adapters → `stream ingest --source all`
9. JSON codec → `--format json` on any lens

**Phase 2: Real-time emission**
10. `_stream_emit` helper + write-detection helpers in `shell-integration.sh`
11. Inject emit into `timew()` wrapper (B events on start/stop/track)
12. Inject emit into `j()` wrapper (A events on write)
13. Inject emit into `l()` wrapper (T events on add/import)
14. TaskWarrior hook scripts (`on-add.stream-emit`, `on-modify.stream-emit`)
15. `stream hooks install/remove/status` subcommands

---

## Key Reuse from Existing Code

| What | From |
|------|------|
| `log_info/error/success` | `lib/core-utils.sh` — source exactly as warrior.sh line 41 |
| Profile env setup | `services/export/export.sh` lines 45-60 |
| `task export` invocation | `lib/export-utils.sh` `export_tasks_json()` |
| `timew export` invocation | `services/export/export.sh` `do_export_time()` |
| Service dispatch pattern | `services/warrior/warrior.sh` `main()` |
| Help heredoc style | `services/warrior/warrior.sh` lines 9-32 |

---

## WW Service Contract Compliance

- `#!/usr/bin/env bash` + `set -euo pipefail`
- Source `$WW_BASE/lib/core-utils.sh` with existence check + inline fallback
- `-h|--help|help` → show_help + exit 0
- exit 0 = success, exit 1 = user/validation error
- All errors → stderr; data → stdout
- Non-interactive safe
- `stream.log` path relative to `$WW_BASE`, never hardcoded

---

## Verification

```bash
ww stream --help
ww stream emit F start abc123 '{"profile":"work"}'
ww stream status
ww stream ingest --source tasks
ww stream view --lens burroughs
ww stream view --lens burroughs --format json | python3 -m json.tool
ww stream ingest --source timew
ww stream view --lens bundy --format ascii
ww stream view --lens hollerith
ww stream view --lens pacioli
ww stream lens list
ww stream bogus; echo "exit: $?"
# idempotent ingest check:
count1=$(wc -l < "$WW_BASE/stream/stream.log")
ww stream ingest --source tasks
count2=$(wc -l < "$WW_BASE/stream/stream.log")
[[ "$count1" -eq "$count2" ]] && echo "dedup ok"
```

---

## Parked (follow-on sessions)

- Remaining lenses: frick.sh, baldwin.sh, dey.sh, cooper.sh (ASCII radial), grant.sh, felt.sh
- Browser `/stream` endpoint + stream panel in browser UI
- `stream monitor` — tail -f mode with SMM plugin hooks
- Dey continuous signal (requires sampling interval config)
- Cooper ASCII radial projection (Python helper for polar math)
- Full TAOO classification across all adapters
- Agent handoff events (S op with HANDOFF action)
- Lists integration: real-time emit when list items are added/modified (pending lists service extension)
