# Service Concept: Reports

## Purpose

Multi-day and multi-source reporting. Where `daily` covers a single day, `reports` covers
ranges, aggregations, and cross-source summaries. Produces structured output for weekly
reviews, monthly closes, project retrospectives, and time audits.

The core problem it solves: extracting meaning from accumulated data across TaskWarrior,
TimeWarrior, JRNL, and Hledger requires knowing each tool's query syntax separately.
`ww reports` makes common reporting patterns one command.

---

## CLI Shape (rough)

All subcommands accept `--since <YYYY-MM-DD>` and `--until <YYYY-MM-DD>` for custom ranges.
`--since` / `--until` are independent; omitting either defaults to the natural range boundary
(e.g. `--since 2026-01-01` with no `--until` runs to today).

```
ww reports weekly   [--since <date>] [--until <date>] [--print]
ww reports monthly  [--since <date>] [--until <date>] [--print]
ww reports project  <name> [<name>...] [--group <group>] [--since <date>] [--until <date>] [--print]
ww reports time     [--since <date>] [--until <date>] [--print]
ww reports list
ww reports show     <id>
```

`project` accepts one or more project/tag names and an optional `--group` flag to scope
to a named group from `config/groups.yaml`. When multiple names or a group are given,
results are shown per-project then totalled.

Default: write artifact to `profiles/<name>/reports/YYYY-MM-DD-<type>.md`, confirm path.
`--print`: stdout only, no write.

---

## Data Model

Artifacts stored at `profiles/<name>/reports/YYYY-MM-DD-<type>.md`.
Naming convention: `2026-04-04-weekly.md`, `2026-04-01-monthly.md`, `2026-04-04-project-infra.md`.
Reports are immutable once written — re-running creates a new timestamped artifact, does not overwrite.

---

## Data Sources

| Source | What it pulls |
|---|---|
| TaskWarrior | Completed, created, modified tasks in range; overdue; by project/tag |
| TimeWarrior | Time by tag, by day, total in range |
| JRNL | Entry count and titles in range |
| Hledger | Income/expense summary for period (optional; skipped if no ledger) |

---

## Dependencies (Tier 1 — no new lib files required)

| Lib | Usage |
|---|---|
| `lib/logging.sh` | All user-facing messages |
| `lib/core-utils.sh` | `ensure_profile_active()` guard |
| `lib/profile-manager.sh` | Artifact path resolution |

External CLIs called directly. Date range parsing is inline bash (no new lib).
`--since` / `--until` accept `YYYY-MM-DD`; `weekly` / `monthly` derive ranges internally.

No new lib files needed at Tier 1.

---

## Relation to Existing Services

- Extends `daily` — daily is the atomic unit; reports aggregate across many days
- No overlap with `export` service (which is raw data dump, not rendered reports)
- Distinct from `dumps` (snapshots for backup) — reports are human-readable summaries

---

## Tier 2 — Template System

Report formats defined in YAML at `resources/reports/templates/<type>.yaml` (global defaults)
with per-profile overrides at `profiles/<name>/reports/templates/<type>.yaml`.

Each template declares:
- `sections:` — ordered list of sections to include (tasks, time, journal, ledger)
- `fields:` — which fields to show per section
- `format:` — heading style, date format, etc.

The Tier 2 config-loader pattern (`lib/config-loader.sh`) handles global → profile override.

---

## Open Questions

1. Should `ww reports show <id>` accept partial ID / fuzzy match?

---

## Tier Estimate

Tier 1 for initial implementation (hardcoded formats, `--since`/`--until`, multi-project).
Tier 2 when YAML template system is added.

---

## Status

ratified — ready for task card when pipeline slot opens
