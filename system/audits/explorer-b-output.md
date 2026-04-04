# Explorer B Audit — Code/Test Reality
Date: 2026-04-04

---

## Executive Summary

1. **GitHub sync is completely untested** — zero BATS coverage across all 6 sync libraries (github-api.sh, sync-pull.sh, sync-push.sh, github-sync-state.sh, sync-detector.sh, github-sync.sh). These are the HIGH FRAGILITY files. CRITICAL.
2. **Profile restore has a data-loss hole** — `profile-manager.sh:1753–1762` deletes the original profile then tries to `mv` the extracted replacement; if `mv` fails (disk full, permissions), the original is gone permanently. CRITICAL.
3. **State file write has no error check on `mv`** — `github-sync-state.sh:182` uses bare `mv` after a jq transform; if it fails, `state.json` is silently lost. CRITICAL.
4. **`set -euo pipefail` missing everywhere** — `bin/ww` has only `set -e`; all 24 lib/ files and all 6 services/custom/ scripts are missing `-u` and `-o pipefail`. Silent failures from unset variables and broken pipes are possible throughout.
5. **Race condition on profile delete** — `delete-utils.sh` checks profile-active status then does `rm -rf` with no lock; a profile can be deleted while in use.

---

## 1. Test Coverage Gaps

### GitHub sync — zero coverage

| File | Exported functions | Tests |
|---|---|---|
| `lib/github-api.sh` | 6 | 0 |
| `lib/sync-pull.sh` | 2 | 0 |
| `lib/sync-push.sh` | 2 | 0 |
| `lib/github-sync-state.sh` | 5 | 0 |
| `lib/sync-detector.sh` | 2 | 0 |
| `services/custom/github-sync.sh` | CLI | 0 |

Untested functions include: `check_gh_cli`, `github_get_issue`, `github_update_issue`, `github_update_labels`, `github_add_comment`, `github_ensure_label`, `sync_pull_issue`, `sync_pull_all`, `sync_push_task`, `sync_push_all`, `init_state_database`, `get_sync_state`, `save_sync_state`, `get_all_synced_tasks`, `remove_sync_state`, `detect_task_changes`, `detect_github_changes`.

### Profile operations — partial coverage

`lib/profile-manager.sh` (1800+ lines):
- Tested: directory creation, `.taskrc` generation, basic CRUD
- **Not tested**: `backup_profile()`, `restore_profile()`, archive extraction with partial failure, concurrent access during restore, profile deletion with active references

### Overall

- ~24 lib/ files, ~6 have any direct tests, ~18 have zero
- Estimated coverage: <15% of code paths
- GitHub sync: 0%

---

## 2. Shell Standards Violations

### Missing `set -euo pipefail`

| File | Current | Missing |
|---|---|---|
| `bin/ww:5` | `set -e` | `-u -o pipefail` |
| `lib/github-api.sh` | nothing | `set -euo pipefail` |
| `lib/sync-pull.sh` | nothing | `set -euo pipefail` |
| `lib/sync-push.sh` | nothing | `set -euo pipefail` |
| `lib/github-sync-state.sh` | nothing | `set -euo pipefail` |
| `lib/sync-detector.sh` | nothing | `set -euo pipefail` |
| `lib/profile-manager.sh` | nothing | `set -euo pipefail` |
| `lib/shell-integration.sh` | nothing | `set -euo pipefail` |
| `lib/logging.sh` | nothing | `set -euo pipefail` |
| `services/custom/github-sync.sh:6` | `set -e` | `-u -o pipefail` |
| All 5 `configure-*.sh` | `set -e` | `-u -o pipefail` |

Impact: unset variable references silently become empty strings; broken pipe in `cmd | jq` silently succeeds.

### Raw echo in lib/ (should use logging.sh)

- `lib/github-api.sh:12,14` — direct `echo` for install instructions
- `lib/delete-utils.sh:28–32` — `echo "ERROR:..."` instead of `log_error`

### Variable quoting

Generally sound. No critical unquoted expansions in destructive paths found.

### `cd` in lib functions

None found. Good.

---

## 3. Dead Code

### `functions/issues/taskwarriortogithubissue.sh`
- Not referenced anywhere in the codebase
- Not sourced, not called, not tested
- Uses `#!/bin/bash` (not `#!/usr/bin/env bash`), no error handling, hardcoded `jq` with no availability check
- Appears to be an abandoned early prototype of the github-sync functionality
- Severity: LOW (not loaded, so doesn't execute)

### `functions/` directory generally
- Unclear which scripts in `functions/journals/`, `functions/ledgers/`, `functions/tasks/`, `functions/times/` are actively used vs legacy. Needs a separate audit sweep.

---

## 4. GitHub Sync Fragility Assessment

### CRITICAL: State file write has no rollback (`github-sync-state.sh:176–184`)

```bash
jq ... "${state_file}" > "${temp_file}" || { rm -f "${temp_file}"; return 1; }
mv "${temp_file}" "${state_file}"   # ← NO ERROR CHECK
chmod 600 "${state_file}"
```

If `mv` fails (disk full, permission error), `state_file` is left stale. Subsequent reads yield wrong sync state — skipped updates or duplicate syncs. Silent data integrity failure.

### HIGH: Silent jq failure in change detection (`sync-detector.sh:43–46`)

```bash
changes=$(echo "${changes}" | jq --arg field "description" '. + {($field): ...}')
```

If jq encounters malformed JSON, `changes` becomes an empty string. Subsequent jq operations on empty string succeed silently. Changes are lost without error.

### HIGH: Hardcoded GitHub API field assumptions (`sync-pull.sh:64–68`)

```bash
title=$(echo "${github_data}" | jq -r '.title // ""')
state=$(echo "${github_data}" | jq -r '.state // ""')
```

Any change in GitHub API response structure silently produces empty strings. No schema validation.

### MEDIUM: Race condition in label management (`sync-push.sh:108–110`)

Between `github_ensure_label` and the actual label add, a concurrent user can delete the label. No retry or post-add validation.

### MEDIUM: Orphaned state on deleted GitHub issue (`sync-pull.sh:31`)

If a GitHub issue is deleted after sync state was saved, `github_get_issue` returns error. The state.json entry persists, creating an orphaned task that will error on every subsequent sync.

### Environment assumptions (undocumented hard dependencies)

- `gh` CLI installed and authenticated (no pre-flight validation before operations)
- `jq` available (no fallback, no availability check at startup)
- `task` command available
- `WORKWARRIOR_BASE` set (sync-pull.sh doesn't validate this before use)
- GitHub rate limits are never checked

---

## 5. Profile Data Integrity Risks

### CRITICAL: Data loss on restore failure (`profile-manager.sh:1753–1762`)

```bash
rm -rf "$profile_base"           # Original deleted here
mv "$extracted_profile" "$profile_base"  # If this fails, original is gone
```

If `mv` fails after `rm -rf` succeeds, the "rollback" instruction tells the user to run restore again — but the archive temp dir was cleaned up. Profile is permanently lost. Requires atomic two-phase commit pattern.

### HIGH: Partial `.taskrc` corruption on sed failure (`profile-manager.sh:159–169`)

Two sequential `sed -i.bak` calls update `data.location` then `hooks.location`. If the first succeeds and the second fails (disk full), `.taskrc` is left in a half-updated state that TaskWarrior will partially read.

### HIGH: Race condition on profile delete (`delete-utils.sh:18–21`)

Active-profile check and `rm -rf` are not atomic. A profile can become active between the check and the delete, resulting in deletion of an in-use profile.

### MEDIUM: Bugwarriorrc world-readable if chmod fails (`profile-manager.sh:84–101`)

```bash
cat > "$bugwarriorrc" << 'EOF'
...credentials...
EOF
chmod 600 "$bugwarriorrc"   # If this fails, file is world-readable at default umask
```

Credentials exposed if filesystem becomes read-only between write and chmod.

### HIGH: Tar symlink following in archive extraction (`profile-manager.sh:1563`)

`tar -xzf` follows symlinks by default. A crafted archive with symlinks could extract files outside the temp directory. Low likelihood (user controls their own archives) but worth noting for the AI agent use case where archives may come from external sources.

---

## Recommendations → TASKS.md cards

### P0 — Critical

| Proposed card | Finding |
|---|---|
| Feeds TASK-SYNC-001 | Add state.json `mv` error check + rollback in github-sync-state.sh |
| Feeds TASK-SYNC-002 | Fix profile restore data-loss (atomic two-phase commit) |
| Feeds TASK-SYNC-003 | Add environment pre-flight validation before sync operations |
| New card needed | Add `set -euo pipefail` to all lib/ and services/custom/ scripts |

### P1 — High

| Proposed card | Finding |
|---|---|
| Feeds TASK-SYNC-001 | GitHub sync integration tests (mock gh CLI) |
| New card needed | Fix race condition in profile delete (flock or recheck-after-lock) |
| New card needed | Fix jq silent failure in sync-detector.sh |

### P2 — Medium

| Proposed card | Finding |
|---|---|
| New card needed | Audit and clean functions/ directory (dead code) |
| Feeds TASK-QUAL-001 | Standardize logging — replace direct echo in lib/ with logging.sh |
| New card needed | Add `--no-symlinks` to tar extraction |
| New card needed | Document GitHub sync failure modes and recovery procedures |
