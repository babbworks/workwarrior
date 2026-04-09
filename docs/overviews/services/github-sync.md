# services/custom/github-sync.sh

**Type:** Executed service script  
**Fragility:** HIGH — user-facing entry point for all sync operations; all sync flows through here

---

## Role

CLI interface for the GitHub two-way sync engine. Routes `ww issues push/pull/sync/enable/disable/status` commands. Runs `sync_preflight()` before any operation that touches GitHub.

---

## Pre-flight (`sync_preflight()`)

Defined in this file. Validates all four preconditions before any sync operation:

| Check | Error category | Fix |
|---|---|---|
| `WORKWARRIOR_BASE` set | `[env-missing]` | Activate a profile: `p-<name>` |
| `jq` installed | `[not-installed]` | `brew install jq` |
| `gh` CLI installed | `[not-installed]` | `brew install gh` |
| `gh` authenticated | `[not-authenticated]` | `gh auth login` |

Returns 0 if all pass. Returns 1 with categorised error message if any fail.

---

## Commands

**`cmd_enable(task_id, issue_number, repo)`**  
Links a task to a GitHub issue. Sets `githubissue`, `githubrepo`, `githubsync` UDAs. Performs initial pull to populate metadata.

**`cmd_disable(task_id)`**  
Sets `githubsync=disabled`. Removes sync state file. Preserves GitHub metadata UDAs.

**`cmd_push([task_id] [--dry-run])`**  
Calls `sync_push_task()` (single) or `sync_push_all()`. Dry-run shows what would be pushed without API calls.

**`cmd_pull([task_id] [--dry-run])`**  
Calls `sync_pull_issue()` (single) or `sync_pull_all()`. Dry-run shows what would be pulled.

**`cmd_sync([task_id] [--dry-run])`**  
Calls `sync_task_bidirectional()` (single) or `sync_all_tasks()` via `lib/sync-bidirectional.sh`.

**`cmd_status()`**  
Lists all synced tasks with their linked GitHub issue, repo, and last sync time.

---

## Entry Point

```bash
main()
  → check WORKWARRIOR_BASE (fail fast if no profile)
  → init_github_sync_config()
  → init_logging()
  → rotate_logs()
  → case "$command" in enable|disable|push|pull|sync|status
```

`enable` calls `sync_preflight()` directly. `push`/`pull`/`sync` call it unless `--dry-run` is set.

---

## Relationship to `ww issues` / `i`

`ww issues push/pull/sync/enable/disable/status` in `bin/ww` routes directly to this script. The `i` shell function in `lib/shell-integration.sh` does the same. Both are synonymous entry points — they must be kept in sync when routing changes.

---

## Profile Override Pattern

Profile-level override: `profiles/<name>/services/custom/github-sync.sh` shadows this global script when that profile is active. Used to provide profile-specific sync behavior without modifying the global script.
