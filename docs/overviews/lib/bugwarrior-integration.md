# lib/bugwarrior-integration.sh

**Type:** Sourced bash library
**Used by:** `services/custom/configure-issues.sh`, `lib/sync-pull.sh`

---

## Role

Manages the coexistence of bugwarrior (one-way pull) and the ww GitHub sync engine (two-way). Prevents the two systems from overwriting each other's UDA data. Bugwarrior injects `github_*` UDAs; the sync engine uses `githubissue`, `githubrepo`, `githubsync` UDAs — these namespaces must not collide.

---

## Functions

**`is_bugwarrior_task(task_uuid)`**
Returns 0 if the task was created by bugwarrior (has `github_number` or similar bugwarrior UDA set). Used to skip bugwarrior-managed tasks during ww sync operations.

**`get_bugwarrior_udas(taskrc_path)`**
Returns list of UDA names in the `.taskrc` that match bugwarrior prefixes (`github_*`, `gitlab_*`, `jira_*`, `trello_*`, `bw_*`).

**`preserve_bugwarrior_udas(task_uuid, update_json)`**
Before applying a sync update to a task, extracts current bugwarrior UDA values and ensures they are not overwritten. Called by `sync_pull_issue()` when updating a task that also has bugwarrior data.

**`init_bugwarrior_task_sync(task_uuid)`**
Initialises ww sync state for a task that was originally created by bugwarrior. Sets up the `githubissue`/`githubrepo` UDAs from the task's `github_number`/`github_repo` bugwarrior UDAs.

**`scan_and_init_bugwarrior_tasks()`**
Scans all tasks with bugwarrior UDAs and calls `init_bugwarrior_task_sync()` for any that don't yet have ww sync state. Used to bootstrap two-way sync for tasks that were previously pull-only.

**`check_bugwarrior_interference(task_uuid)`**
Returns 0 if bugwarrior has modified the task since the last ww sync (by comparing `githubupdatedat` with sync state timestamp). Used to detect when bugwarrior has overwritten ww sync data.

**`merge_sync_udas(task_uuid, bugwarrior_data, sync_data)`**
Merges bugwarrior UDA values with ww sync UDA values, giving precedence to ww sync data for fields both systems manage.

**`show_bugwarrior_status()`**
Displays count of bugwarrior-managed tasks, ww-synced tasks, and tasks managed by both.

---

## Two-Engine Model

Bugwarrior and ww github-sync are separate engines with separate UDA namespaces:

| Engine | Direction | UDAs |
|---|---|---|
| bugwarrior | GitHub → TW (pull only) | `github_number`, `github_repo`, `github_url`, `github_title`, etc. |
| ww github-sync | TW ↔ GitHub (two-way) | `githubissue`, `githubrepo`, `githubsync`, `githuburl` |

A task can be managed by both: bugwarrior pulls metadata, ww sync handles two-way state. This file manages that coexistence.

## Changelog

- 2026-04-10 — Initial version
