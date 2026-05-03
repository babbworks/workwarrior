# Service Concept: Definitions

## Purpose

A profile-scoped glossary service. Stores, retrieves, and manages definitions for terms,
abbreviations, acronyms, and concepts relevant to a profile's domain. Definitions are
durable, searchable, and can be referenced from other services.

The core problem it solves: domain-specific terminology accumulates in every project —
abbreviations, internal names, agreed concepts — and currently lives nowhere persistent.
`ww definitions` makes vocabulary a first-class profile artifact.

---

## CLI Shape (rough)

```
ww definitions add    <term> [--print]             — add definition via sequential prompts; --editor to open $EDITOR
ww definitions lookup <term>                        — exact or fuzzy match lookup
ww definitions list   [--tag <tag>] [--letter <A>] — list all terms, filterable by tag or initial letter
ww definitions edit   <term> [--editor]            — re-run prompts with inherited text; --editor opens $EDITOR
ww definitions delete <term>                        — remove a definition (prompts confirm)
ww definitions search <query>                       — full-text search across all definitions and body text
ww definitions export [--format <md|json|csv>]     — export full glossary
```

---

## Data Model

Each definition stored as a single entry in `profiles/<name>/definitions/<term-slug>.md`.

File format:

```markdown
# API Gateway

Tags:     infrastructure, networking
Added:    2026-04-04
Updated:  2026-04-04

## Definition
A server that acts as an entry point for clients, routing requests to backend services.

## Notes
Used internally to refer specifically to the Kong instance on the infra profile.

## Also See
- Load Balancer
- Service Mesh
```

Terms with the same slug (e.g. two meanings of "API") differentiated by a numeric suffix:
`api-gateway.md`, `api-gateway-2.md` — user prompted on collision.

---

## Sequential Prompt UX

Uses the sequential prompt pattern (see `sequential-prompt-pattern.md`):

Sections: Definition, Notes, Also See, Tags.

`--editor` bypasses prompts and opens pre-populated file in `$EDITOR`.
Inherited text offered on edit.

---

## Dependencies (Tier 1 — no new lib files required)

| Lib | Usage |
|---|---|
| `lib/logging.sh` | All user-facing messages |
| `lib/core-utils.sh` | `ensure_profile_active()` guard |
| `lib/profile-manager.sh` | Definitions directory path resolution |

Fuzzy lookup via `grep -i` across filenames and content. Export via inline `awk`/`printf`.
No new lib files needed at Tier 1.

---

## Relation to Existing Services

- Distinct from `decisions` — decisions record choices; definitions record what things mean
- Distinct from `bases` — bases is a full knowledge base engine; definitions is a lightweight
  structured glossary
- `Also See` cross-references are plain text (term names), not hard links at Tier 1
- Potential integration: `ww reports` or `ww sites` could include the glossary as a section

---

## Tags

Hybrid — freeform accepted, optional shared vocabulary. Same model as plans and decisions.

---

## Lookup Behaviour

`lookup` displays the first line of the Definition section only — one-liner output.
Full entry available via `ww definitions show <term>`.

---

## Deferred to Tier 2

- Navigable Also See — unclear what the interaction would be; parked pending use in practice.

---

## Tier Estimate

Tier 1: add/lookup (one-liner)/show (full)/list/edit/delete/search/export, sequential
prompts, hybrid tags, slug-based storage, fuzzy grep search, md/json/csv export.
Tier 2: navigable cross-references, sites/reports integration, shared vocabulary enforcement.

---

## Status

ratified — ready for task card when pipeline slot opens
