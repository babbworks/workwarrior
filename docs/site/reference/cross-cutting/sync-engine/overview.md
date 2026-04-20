# GitHub Sync Engine — Cross-Cutting Overview

**Scope:** All files that implement two-way TaskWarrior ↔ GitHub sync
**Entry point:** `services/custom/github-sync.sh`
**Fragility:** HIGH across all files listed below

---

## File Map

```
services/custom/github-sync.sh      CLI entry point — sync_preflight, command routing
lib/github-api.sh                   GitHub REST API via gh CLI
lib/github-sync-state.sh            Sync state persistence (per-task JSON files)
lib/sync-detector.sh                Change detection (task and GitHub sides)
lib/sync-pull.sh                    GitHub → TaskWarrior pull
lib/sync-push.sh                    TaskWarrior → GitHub push
lib/sync-bidirectional.sh           Orchestrates pull+push with conflict window
lib/conflict-resolver.sh            Last-write-wins conflict resolution
lib/annotation-sync.sh              TW annotations ↔ GitHub comments
lib/field-mapper.sh                 Field translation between TW and GitHub formats
lib/error-handler.sh                GitHub-specific error classification and recovery
lib/bugwarrior-integration.sh       Coexistence with bugwarrior one-way pull
```

---

## Full Sync Cycle

```
ww issues sync
  → sync_preflight()                 Validate: gh CLI, jq, WORKWARRIOR_BASE
  → sync_all_tasks()                 [sync-bidirectional.sh]
    → for each synced task UUID:
      → get_sync_state(uuid)         [github-sync-state.sh] — load last known state
      → detect_task_changes()        [sync-detector.sh] — TW side changed?
      → detect_github_changes()      [sync-detector.sh] — GitHub side changed?
      → determine_sync_action()      push / pull / conflict / none
      → if conflict:
          resolve_conflict_last_write_wins()  [conflict-resolver.sh]
      → if push:
          sync_push_task()           [sync-push.sh]
            → github_update_issue()  [github-api.sh]
            → sync_annotations_to_comments()  [annotation-sync.sh]
            → save_sync_state()      [github-sync-state.sh]
      → if pull:
          sync_pull_issue()          [sync-pull.sh]
            → github_get_issue()     [github-api.sh]
            → tw_update_task()       [taskwarrior-api.sh]
            → sync_comments_to_annotations()  [annotation-sync.sh]
            → save_sync_state()      [github-sync-state.sh]
```

---

## State File Location

Each synced task has a state file at:
```
$WORKWARRIOR_BASE/.task/github-sync/<uuid>.json
```

Contains: task UUID, GitHub issue number, repo, last sync timestamp, last known task state JSON, last known GitHub issue JSON. Used by the detector to determine what changed since the last sync.

---

## Known Data Integrity Fixes (TASK-SYNC-002)

Three critical bugs were fixed:

1. **`github-sync-state.sh:save_sync_state()`** — Now uses two-phase commit (write to temp, then `mv`). Previously bare `mv` with no error check could silently lose state.

2. **`sync-detector.sh:detect_task_changes()`** — Now validates both JSON inputs with `jq empty` before comparison. Previously jq failure left `changes` as empty string and code continued silently.

3. **`profile-manager.sh:restore_profile()`** — Now creates safety backup before `rm -rf` of original. Previously deleted original before confirming replacement succeeded.

---

## Pre-flight Error Categories

All sync operations run `sync_preflight()` first. Error categories are bracket-tagged for programmatic parsing:

| Category | Meaning |
|---|---|
| `[env-missing]` | `WORKWARRIOR_BASE` not set — no active profile |
| `[not-installed]` | `gh` CLI or `jq` not found |
| `[not-authenticated]` | `gh auth login` required |
| `[rate-limited]` | GitHub API rate limit — retry after delay |
| `[not-found]` | Issue deleted on GitHub — orphan entry |
| `[permission-denied]` | Insufficient GitHub repo permissions |

---

## Integration Test Suite

`tests/run-integration-tests.sh` — requires a live GitHub-authenticated test profile. Tests:
- 24.1: Full Push Cycle
- 24.2: Full Pull Cycle
- 24.3: Conflict Resolution
- 24.4: Error Handling
- 24.5: Batch Operations

Must pass clean before AND after any change to HIGH FRAGILITY files.

## Changelog

- 2026-04-10 — Initial version
