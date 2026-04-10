# lib/sync-bidirectional.sh

**Type:** Sourced bash library
**Part of:** GitHub Sync Engine — see `cross-cutting/sync-engine/overview.md`
**Fragility:** HIGH — orchestrates the full sync cycle; conflict window is highest here

---

## Role

Orchestrates the complete bidirectional sync cycle. Calls the detector, resolver, pull, and push in the correct order. The conflict window — the period where both sides could have changed — is managed here.

---

## Functions

**`sync_task_bidirectional(task_uuid)`**
Full sync for a single task:
1. Load sync state
2. Fetch current task from TW and current issue from GitHub
3. Run both change detectors
4. If both changed → `resolve_conflict_last_write_wins()`
5. If only task changed → `sync_push_task()`
6. If only GitHub changed → `sync_pull_issue()`
7. If neither changed → return 0 (no-op)

**`sync_all_tasks()`**
Iterates all synced tasks (from `get_all_synced_tasks()`), calls `sync_task_bidirectional()` per task. Reports total/push/pull/conflict/skip/failed counts.

---

## Conflict Window Management

The conflict window opens when the last sync state is read and closes when the new state is saved. During this window, a concurrent modification on either side would be missed. The window is kept as short as possible by:
1. Reading both sides before making any writes
2. Writing sync state immediately after each successful operation
3. Not batching writes — each task's state is saved before moving to the next

---

## Error Isolation

Failures on individual tasks do not abort the full sync. Each task is processed independently. Failed tasks are counted and reported in the summary. The sync log records the specific error for each failure.
