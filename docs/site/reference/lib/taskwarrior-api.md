# lib/taskwarrior-api.sh

**Type:** Sourced bash library
**Used by:** `lib/sync-pull.sh`, `lib/sync-push.sh`, `lib/sync-bidirectional.sh`, `lib/bugwarrior-integration.sh`

---

## Role

Thin wrapper around the `task` CLI for programmatic task reads and writes. All TaskWarrior operations in the sync engine go through this file — no direct `task` calls in sync logic. Respects `TASKRC` and `TASKDATA` env vars set by profile activation.

---

## Read Functions

**`tw_get_task(task_uuid)`**
Returns full task JSON for a UUID. Uses `task export uuid:<uuid>` and extracts the first result. Returns empty string if task not found.

**`tw_get_field(task_uuid, field_name)`**
Returns a single field value for a task. Uses `task _get <uuid>.<field>`.

**`tw_get_task_by_issue(issue_number, repo)`**
Finds a task by its `githubissue` and `githubrepo` UDA values. Returns the task UUID or empty string.

**`tw_task_exists(task_uuid)`**
Returns 0 if the task exists (any status including completed/deleted).

**`tw_get_synced_tasks()`**
Returns newline-separated list of UUIDs for tasks with `githubsync=enabled`.

---

## Write Functions

**`tw_update_task(task_uuid, field, value)`**
Sets a single field on a task using `task <uuid> modify <field>:<value>`. Uses `rc.confirmation=no` to suppress interactive prompts. Returns non-zero on failure — callers must check.

**`tw_update_task_fields(task_uuid, fields_json)`**
Batch update multiple fields from a JSON object. Builds a single `task modify` command with all fields to minimise hook invocations.

**`tw_add_annotation(task_uuid, annotation_text)`**
Adds an annotation to a task using `task <uuid> annotate`.

---

## Design Notes

- All functions pass `TASKRC` and `TASKDATA` explicitly via env — never rely on ambient shell state
- `rc.confirmation=no` is set on all write operations — sync must never block waiting for user input
- `rc.verbose=nothing` suppresses TaskWarrior's output on writes — only errors surface
- Return codes are meaningful: 0 = success, non-zero = failure. Callers in sync-pull/push check every write

## Changelog

- 2026-04-10 — Initial version
