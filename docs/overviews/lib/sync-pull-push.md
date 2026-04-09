# lib/sync-pull.sh + lib/sync-push.sh

**Type:** Sourced bash libraries  
**Fragility:** HIGH — can overwrite local task data (pull) or create/modify remote GitHub issues (push)

---

## sync-pull.sh

### Role
Pulls GitHub issue state into TaskWarrior. Reads from GitHub, writes to TaskWarrior. One-way: GitHub is the source of truth for the fields it manages.

### `sync_pull_issue(task_uuid, issue_number, repo)`

**Orphan detection:** If `github_get_issue()` returns `[not-found]`, the issue was deleted on GitHub. Instead of hard-erroring on every sync, logs a warning and returns 0 (skip). User is told to run `github-sync disable <uuid>` to clean up.

**Change detection:** If sync state exists, calls `detect_github_changes()` first. If no changes detected, returns 0 without writing anything.

**Fields pulled:**
- `description` ← issue title
- `status` ← issue state (via `map_github_to_status()`)
- `priority` ← labels (via `map_labels_to_priority()`)
- `githubissue`, `githuburl`, `githubrepo`, `githubauthor` ← metadata UDAs
- `entry` ← issue `createdAt` (first sync only, if not already set)
- `end` ← issue `closedAt` (if status becomes completed)

**UDA failure handling:** All metadata UDA writes use `|| { log_warning ...; uda_failures=$((uda_failures+1)); }` — failures are counted and surfaced, not silenced with `2>/dev/null`. Caller receives non-zero if any UDA write failed.

**Tag sync:** Explicitly deferred to TASK-SYNC-005. Labels → tags mapping is skipped with a comment.

### `sync_pull_all()`
Iterates all synced tasks (from `get_all_synced_tasks()`), calls `sync_pull_issue()` per task. Reports total/success/failed counts.

---

## sync-push.sh

### Role
Pushes TaskWarrior task state to GitHub. Reads from TaskWarrior, writes to GitHub. One-way: TaskWarrior is the source of truth for the fields it manages.

### `sync_push_task(task_uuid, issue_number, repo)`

**Change detection:** If sync state exists, calls `detect_task_changes()` first. If no changes, returns 0.

**Fields pushed:**
- Issue title ← `description` (truncated to 256 chars via `truncate_title()`)
- Issue state ← `status` (via `map_status_to_github()`)
- Labels ← `priority` (via `map_priority_to_label()`) + tags (via `map_tags_to_labels()`)
- Comments ← annotations (via `sync_annotations_to_comments()`)

**Label management:** Gets current labels from GitHub, determines what to add/remove, calls `github_ensure_label()` for any new labels before adding them.

**State update:** After push, re-fetches the issue from GitHub and saves sync state with the fresh GitHub data.

### `sync_push_all()`
Same pattern as `sync_pull_all()`.

---

## Shared Constraints

- Both files source `lib/github-api.sh`, `lib/taskwarrior-api.sh`, `lib/github-sync-state.sh`, `lib/field-mapper.sh`, `lib/sync-detector.sh`, `lib/annotation-sync.sh`, `lib/logging.sh`
- Never called directly — always via `services/custom/github-sync.sh` which runs `sync_preflight()` first
- Integration tests required for any change: `./tests/run-integration-tests.sh` on a test profile
