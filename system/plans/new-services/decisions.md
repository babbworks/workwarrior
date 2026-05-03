# Service Concept: Decisions

## Purpose

A decision log service. Records decisions with context, options considered, rationale,
and outcome. Decisions are durable, addressable, and retrievable. Inspired by Architecture
Decision Records (ADRs) but general-purpose — not limited to technical choices.

The core problem it solves: decisions made in a profile context (what tool to use, which
approach to take, what was agreed) currently live in journals or are lost entirely. `ww decisions`
makes them first-class, searchable records that persist alongside other profile data.

---

## CLI Shape (rough)

```
ww decisions add    [--title <title>] [--status <status>] [--editor]  — sequential prompts; --editor opens $EDITOR instead
ww decisions list   [--status <filter>] [--tag <tag>]                 — list all decisions, filterable
ww decisions show   <id>                                               — display full decision record
ww decisions edit   <id> [--editor]                                    — re-run sequential prompts; --editor opens $EDITOR directly
ww decisions status <id> <status>                                      — update status (open/accepted/superseded/deprecated)
ww decisions search <query>                                            — full-text search across all decisions
```

`add` uses sequential prompt pattern (see `sequential-prompt-pattern.md`) — Context,
Options Considered, Decision, Outcome, Tags — with `--editor` to bypass prompts.

---

## Data Model

Each decision stored as a markdown file at `profiles/<name>/decisions/<id>-<slug>.md`.
IDs are sequential integers (0001, 0002, …), zero-padded for sort stability.

File format:

```markdown
# 0001 — Use hledger for ledger tracking

Date:     2026-04-04
Status:   accepted
Tags:     tooling, finance

## Context
[Why this decision was needed]

## Options Considered
- Option A: ...
- Option B: ...

## Decision
[What was decided and why]

## Outcome
[Observed result, filled in later]
```

`ww decisions add` prompts for each section interactively if no inline flags given.
`--title` and `--status` skip those prompts.

---

## Dependencies (Tier 1 — no new lib files required)

| Lib | Usage |
|---|---|
| `lib/logging.sh` | All user-facing messages |
| `lib/core-utils.sh` | `ensure_profile_active()` guard |
| `lib/profile-manager.sh` | Decision store path resolution |

`$EDITOR` used for `edit` subcommand. Sequential ID generation: `ls decisions/ | wc -l + 1`.
Full-text search via `grep -r` over the decisions directory — no indexer needed at Tier 1.

No new lib files needed at Tier 1.

---

## Relation to Existing Services

- Distinct from `journal` — journal is timestamped free prose; decisions are structured records
- Distinct from `daily` — daily captures what happened; decisions capture why choices were made
- Potential integration: `ww daily review` could list decisions made today (future enhancement)

---

## Tag Model

Tags are hybrid: freeform strings accepted freely, but `config/tags.yaml` (or a
decisions-specific `decisions/tags.yaml`) can define a shared vocabulary for autocomplete
and filtering. Unknown tags are accepted without error — no enforcement at Tier 1.

---

## Open Questions

1. Should `superseded` status reference the superseding decision ID inline?
   (e.g. `Superseded-by: 0004`) — left open pending use in practice.

---

## Deferred to Tier 2

- Task linking (`task:<uuid>`) — useful but requires a simple, intuitive resolution
  mechanism that doesn't exist yet. Park until task cross-reference pattern is established.

---

## Tier Estimate

Tier 1: markdown files, `$EDITOR`, grep search, sequential IDs, hybrid tags.
Tier 2: task linking, tag vocabulary enforcement, supersedes references.

---

## Status

ratified — ready for task card when pipeline slot opens
