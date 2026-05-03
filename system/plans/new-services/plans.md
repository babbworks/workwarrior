# Service Concept: Plans

## Purpose

A structured planning document service. Stores and retrieves plans tied to a profile —
project plans, roadmaps, approaches, strategies. Each plan is a named, versioned document
that can evolve over time with a clear status and history.

The core problem it solves: planning documents currently live outside the profile context
(notes apps, loose files, system/plans/) with no consistent structure, no status tracking,
and no link to the work they describe. `ww plans` makes plans first-class profile artifacts.

---

## CLI Shape (rough)

```
ww plans add    <name> [--editor] [--print]   — create via sequential prompts; --editor opens $EDITOR instead
ww plans list   [--status <filter>]          — list plans with name, date, status
ww plans show   <name|id>                    — display plan document
ww plans edit   <name|id> [--editor]         — re-run sequential prompts; --editor opens $EDITOR directly
ww plans status <name|id> <status>        — update status (draft/active/complete/archived)
ww plans log    <name|id> <note>          — append timestamped update note to Updates section
ww plans history <name|id>               — list all plans sharing this name
```

---

## Naming and Versioning

Plans can share a name. The date is always visible in the filename and in the document header.
Collision resolution:
- Different name → `<slug>-<YYYY-MM-DD>.md`
- Same name, same date → `<slug>-<YYYY-MM-DD>-v2.md`, `-v3.md`, etc.
- `ww plans list` groups by name and shows all versions with dates in clear view
- `ww plans history <name>` lists all versions chronologically

## Data Model

Plans stored at `profiles/<name>/plans/<slug>-<YYYY-MM-DD>.md` (or `-v2`, `-v3` suffix).

File format (the default template):

```markdown
# Plan: Migrate to new task schema

Status:   draft
Created:  2026-04-04
Updated:  2026-04-04
Tags:

## Goal


## Approach


## Steps


## Updates
- 2026-04-04: Created
```

`ww plans log` appends a timestamped line to the Updates section.

## Sequential Prompt UX

See `sequential-prompt-pattern.md` in this directory — this service is the canonical
implementation of that pattern.

On `ww plans add <name>`:
- If a prior plan with the same name exists, its text for each field is shown as the default
- Each section is presented one at a time: label shown, previous value displayed, cursor ready
- Pressing Enter accepts the previous text unchanged; typing replaces it
- Sections: Goal, Approach, Steps, Tags (Updates pre-populated with created timestamp)
- On `ww plans edit`: same flow, all fields inherited from the chosen version

On first-ever plan with this name: prompts shown with empty defaults.

---

## Dependencies (Tier 1 — no new lib files required)

| Lib | Usage |
|---|---|
| `lib/logging.sh` | All user-facing messages |
| `lib/core-utils.sh` | `ensure_profile_active()` guard |
| `lib/profile-manager.sh` | Plans directory path resolution |

`$EDITOR` for `add` and `edit`. Status stored in frontmatter parsed with `awk`.
No new lib files needed at Tier 1.

---

## Relation to Existing Services

- Distinct from `decisions` — decisions record a resolved choice; plans describe how
  work will be done (before and during execution)
- Distinct from `daily` — daily is a time-unit artifact; plans are persistent documents
- Complements `reports` — a report could reference the active plan for a project

---

## Tags

Hybrid — same model as decisions: freeform accepted, optional shared vocabulary in
`config/tags.yaml`. No enforcement at Tier 1.

---

## Deferred

- Step completion percentage — not a required feature; dropped from scope.
- Custom templates — Tier 2: user defines templates by answering prompt-by-prompt
  (header name, then prompt text for each), same flow as questions service.
  Templates stored as YAML at `profiles/<name>/plans/templates/<type>.yaml`.

---

## Tier Estimate

Tier 1: sequential prompt UX with inheritance, date+version naming, add/list/show/edit/
status/log/history, hybrid tags, awk frontmatter parsing.
Tier 2: user-defined templates via prompt-by-prompt creation (questions-service pattern).

---

## Status

ratified — ready for task card when pipeline slot opens
