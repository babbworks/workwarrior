# Service Concept: Daily

## Purpose

A daily rhythm service. Aggregates data from all active profile tools (TaskWarrior, TimeWarrior, JRNL, Hledger) into structured daily artifacts — morning standups, end-of-day reviews, and day-over-day context threads.

The core problem it solves: a user with an active profile has no single "what happened today / what's next" view. They must query each tool separately. `ww daily` makes the day-unit a first-class concept.

---

## CLI Shape (rough)

```
ww daily standup [--print]    — write morning standup artifact; --print outputs to stdout only
ww daily review  [--print]    — write end-of-day artifact; --print outputs to stdout only
ww daily log [message]        — append freeform note to today's artifact
ww daily show [date]          — display artifact (default: today; accepts YYYY-MM-DD)
ww daily list                 — list all days with recorded artifacts
```

Default behaviour for `standup` and `review`: write to `profiles/<name>/daily/YYYY-MM-DD.md`
and confirm path on success. `--print` suppresses the write and sends output to stdout only.

---

## Data Model

Stores artifacts in `profiles/<name>/daily/YYYY-MM-DD.md` — one file per day.
Each file is a structured markdown document with sections for:
- Standup snapshot (generated)
- Review snapshot (generated)
- Freeform log entries (appended by `ww daily log`)

Artifacts are generated on demand and appended-to, never silently overwritten.

---

## Data Sources

| Source | What it pulls |
|---|---|
| TaskWarrior | Due today, in-progress, completed today, overdue |
| TimeWarrior | Time tracked today by tag/project |
| JRNL | Journal entries written today |
| Hledger | Transactions posted today (optional / if ledger active) |

---

## Dependencies (Tier 1 — no new lib files required)

| Lib | Usage |
|---|---|
| `lib/logging.sh` | All user-facing messages |
| `lib/core-utils.sh` | `ensure_profile_active()` guard |
| `lib/profile-manager.sh` | `get_profile_base_dir()` for artifact path resolution |

External CLIs (task, timew, jrnl) called directly via subshell with TASKRC/TASKDATA/TIMEWARRIORDB
already set by active profile. Checked at runtime per subcommand — absence degrades gracefully
(section skipped with a `[not available]` note in the artifact).

No new lib files needed at Tier 1.

---

## Relation to Existing Services

- Complements `journal` service (JRNL) — does not replace it; daily log is distinct from journal
- Complements `warrior` (TaskWarrior) — reads but does not write task data
- No overlap with `reports` (which is multi-day aggregation)

---

## Open Questions

1. Should standup format be configurable via a YAML template? (Tier 2 promotion trigger)
2. Should past-day artifacts be editable via `ww daily edit [date]`?

---

## Tier Estimate

Tier 2 (template-driven standup/review format) or Tier 1 if format is hardcoded initially.
Start Tier 1, promote to Tier 2 on first template request.

---

## Status

ratified — ready for task card when pipeline slot opens
