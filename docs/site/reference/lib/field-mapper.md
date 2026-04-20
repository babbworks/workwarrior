# lib/field-mapper.sh

**Type:** Sourced bash library  
**Fragility:** HIGH — silent mapping errors cause data corruption across sync

---

## Role

Bidirectional field translation between TaskWarrior and GitHub formats. All field mapping goes through this file — no ad-hoc format conversion in sync-pull or sync-push.

---

## Status Mapping

**`map_status_to_github(tw_status)`**  
`pending` → `OPEN`, `completed` → `CLOSED`, `deleted` → `CLOSED`, `waiting` → `OPEN`

**`map_github_to_status(gh_state, state_reason)`**  
`OPEN` → `pending`, `CLOSED` + `completed` → `completed`, `CLOSED` + `not_planned` → `deleted`, `CLOSED` (other) → `completed`

---

## Priority / Label Mapping

**`map_priority_to_label(priority)`**  
`H` → `priority:high`, `M` → `priority:medium`, `L` → `priority:low`, empty → empty

**`map_labels_to_priority(labels_json)`**  
Scans label array for `priority:*` labels. Returns `H`/`M`/`L` or empty.

**`get_priority_labels(labels_json)`**  
Returns comma-separated list of priority labels currently on an issue (used to determine what to remove on push).

---

## Tag / Label Mapping

**`map_tags_to_labels(tags_json)`**  
Converts TaskWarrior tags array to comma-separated GitHub label string. Filters out `SYSTEM_TAGS`.

**`map_labels_to_tags(labels_json)`**  
Converts GitHub label array to space-separated TaskWarrior tags. Filters out priority labels.

**`filter_system_tags(tags_json)`**  
Removes tags in `SYSTEM_TAGS` set from a tag array. System tags: `ACTIVE`, `READY`, `PENDING`, `BLOCKED`, `WAITING`, `NEXT`, `OVERDUE`.

**`sanitize_label_name(name)`**  
Converts TaskWarrior tag to valid GitHub label name (lowercase, spaces to hyphens).

---

## UDA Body Block (bidirectional)

**`serialize_udas_to_body_block(task_json)`**  
Appends a `<!-- ww-udas: {...} -->` JSON block to the issue body containing UDA values. Used to round-trip UDA data through GitHub issue bodies.

**`parse_body_block_to_udas(body)`**  
Extracts and parses the `<!-- ww-udas: {...} -->` block from an issue body. Returns JSON object of UDA key-value pairs.

---

## Utilities

**`truncate_title(description, max_length)`** — Truncates to max_length with `...` suffix.  
**`format_timestamp(iso8601)`** — Converts ISO 8601 to TaskWarrior date format.  
**`add_taskwarrior_prefix(text)`** / **`add_github_prefix(text)`** — Annotation formatting.

---

## SYSTEM_TAGS

Tags that are never modified by sync operations. Defined as a bash array at the top of the file. Any tag in this set is filtered out of both push and pull operations. Modifying this set changes sync behavior globally — update with care.

## Changelog

- 2026-04-10 — Initial version
