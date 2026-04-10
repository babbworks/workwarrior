# lib/sync-detector.sh + lib/github-sync-state.sh

**Type:** Sourced bash libraries  
**Fragility:** HIGH — false negatives skip sync; false positives cause spurious writes; state corruption breaks incremental sync

---

## sync-detector.sh

### Role
Determines what changed between the last known state and the current state, for both TaskWarrior tasks and GitHub issues. Drives the decision of whether to push, pull, or skip.

### `detect_task_changes(task_uuid, current_state_json, last_state_json)`

Compares current task JSON against last-known task state. Returns:
- `0` — changes detected (outputs JSON change object to stdout)
- `1` — no changes

**Input validation (TASK-SYNC-002 fix):** Both JSON inputs are validated with `jq empty` before comparison. If either is malformed, returns 1 with `[not valid JSON]` error. Previously, jq failure left `changes` as empty string and code continued silently.

**Fields compared:** `description`, `status`, `priority`, `tags` (order-independent — sorted before comparison), `annotations`.

**Tag comparison:** Tags are sorted before comparison so `["b","a"]` and `["a","b"]` are treated as identical.

### `detect_github_changes(issue_number, current_github_json, last_github_json)`

Same pattern for GitHub issue state. Fields compared: `title`, `state`, `labels`, `comments`.

### `determine_sync_action(task_uuid)`

Reads sync state, calls both detectors, returns: `push`, `pull`, `conflict`, or `none`.

### `detect_new_annotations(task_uuid, last_state_json)` / `detect_new_comments(issue_number, last_github_json)`

Returns new annotations/comments since last sync. Used by `annotation-sync.sh`.

### `has_conflicts(task_uuid)`

Returns 0 if both task and GitHub changed since last sync (conflict condition).

---

## github-sync-state.sh

### Role
Persists sync state between runs. Each synced task has a JSON state file at `$WORKWARRIOR_BASE/.task/github-sync/<uuid>.json` containing the last-known task state and last-known GitHub state.

### State File Format

```json
{
  "task_uuid": "...",
  "github_issue": "42",
  "github_repo": "owner/repo",
  "last_sync": "2026-04-09T10:00:00Z",
  "last_task_state": { ...task JSON... },
  "last_github_state": { ...issue JSON... }
}
```

### `init_state_database()`
Creates `$WORKWARRIOR_BASE/.task/github-sync/` directory if it doesn't exist.

### `save_sync_state(task_uuid, task_json, github_json)`

**Two-phase commit (TASK-SYNC-002 fix):** Writes to a temp file first, then atomically moves to the final path. If the move fails, the original state is preserved. Previously used bare `mv` with no error check — if `mv` failed, `state.json` was silently lost.

### `get_sync_state(task_uuid)`
Returns the state JSON for a task, or empty string if not synced.

### `is_task_synced(task_uuid)`
Returns 0 if a state file exists for the task.

### `get_all_synced_tasks()`
Returns newline-separated list of task UUIDs that have sync state files.

### `remove_sync_state(task_uuid)`
Deletes the state file. Called by `github-sync disable`.

## Changelog

- 2026-04-10 — Initial version
