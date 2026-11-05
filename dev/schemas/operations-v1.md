# Scoped operational backend v1

TASK-OPS-001 / NA-367. Optional provider service. Python 3.11 standard library.

The store lives outside repositories and existing profiles. Reads never initialize it. Init previews first; apply requires the exact preview hash. Local POSIX SQLite transactions serialize mutation of records, retained versions, events and request receipts. Organization and issued instance identity must match store metadata. Profile is explicit per call and is not a separate security principal. The initialized OS UID controls writes; actor labels never grant authority.

## Actions and lifecycle

`assign` retains instructions, exact native bindings, acceptance requirements, input artifact references and bounded attempt/concurrency policy. `start` requires a current assignment pin and creates an independently issued attempt. `heartbeat` and `finish` require current attempt pins. Finish retains a distinct unreviewed return with artifact metadata and measured/reported/estimated usage. External artifact metadata is an attributed report, not independent file verification. `cancel` requests cancellation when attempts are open; it does not claim a process was stopped. No action executes commands or grants native review acceptance.

`observe` retains producer/source-event identity, occurred and recorded time, actor, object, category and source data. Repeated identical source events are reused; changed content under that identity is refused. Native event namespaces are reserved. New request keys do not duplicate a previously recorded producer event. Unknown unit labels remain visible and are flagged unregistered.

Every mutation is plan/apply. Plans bind scope, normalized payload, request key and exact referenced versions/hashes. Apply validates the plan in a writer transaction; replay returns the earlier receipt before testing dependencies for a new effect. Snapshot and cursor reads are explicit; empty is different from unavailable or failed. This is one local store, not an atomic transaction across company/provider databases.

## Lens results

`ww-lens-result/v1` carries the inventor name, descriptive label, method version, typed data and derivation metadata: scope, input cursor/hash, eligible/excluded event counts, [start,end) bounds, as-of clock, filters and warnings. Reconstruct attempt intervals from history before clipping to a requested window. Bundy/Board require an explicit as-of timestamp. Bundy distinguishes exact attempt microseconds, per-actor interval unions and elapsed union; overlapping attempts do not become fabricated actor effort.

Burroughs inspects all selected categories. Baldwin compares native record revisions, distinguishing missing fields, nulls and typed values. Frick shows native recorded transitions. Bundy reconstructs clipped intervals. Board shows open attempts and heartbeat age. Felt counts eligible observation events. Grant defaults to operational counts. Explicit alternate Felt/Grant methods compute first/second differences on a bounded UTC-hour grid, separate from business value. Dey exposes explicitly defined event-rate, type richness and entropy features. Cooper renders the identical rate samples in UTC with dates retained and absolute scales. Hollerith retains all event identities per cell. Pacioli is explicitly cumulative counting, separate from signed/double-entry accounting.

Density and signal exclude derived and administrative events. Names preserve lineage; method versions preserve exact semantics. No geometric or signal result proves productivity, fatigue, causation or permission. The legacy `ww stream` format and logs are neither migrated nor rewritten. Existing historical defect repairs remain separate work.

## Example

```sh
ww operations capabilities
ww operations --store DATA init --organization COMPANY_ID
# Inspect, then repeat with --apply --plan-sha256 HASH.
ww operations --store DATA --scope-file SCOPE.json snapshot
ww operations --store DATA --scope-file SCOPE.json plan assign --input INPUT.json --key assignment-one
ww operations --store DATA --scope-file SCOPE.json apply --input PLAN.json --plan-sha256 HASH
ww operations --store DATA --scope-file SCOPE.json lens bundy --as-of 2026-11-05T12:00:00Z
```

`SCOPE.json` contains organization, instance and profile. `request --input -` is the structured subprocess adapter. CLI help lists implemented actions. No service, timer, agent provider, Taskwarrior mirror or cross-tool sync is enabled implicitly.

The normative formulas, units, invariants and qualification limits are in [lens-mathematics-v1.md](lens-mathematics-v1.md). Inventor names are not substitutes for method identities or empirical validation.
