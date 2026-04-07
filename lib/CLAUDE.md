# lib/CLAUDE.md — Workwarrior Library Layer

Read this before touching any file in `lib/`. These are sourced bash libraries — not executed scripts. The rules here differ from `bin/` and `services/`.

---

## Critical Rule: Sourced vs Executed

`lib/` files are **sourced**, not executed. This means:

- **Never add `set -euo pipefail`** to any lib file. It propagates into every caller's shell context and breaks error handling across the entire process. Use `${var:-}` defensive guards instead of relying on `set -u`.
- **No `exit` calls** in lib functions — use `return` with exit codes only.
- **No `cd`** — use absolute paths always.

---

## Access Policy

### SERIALIZED — one writer at a time, never parallel

| File | Reason |
|---|---|
| `shell-integration.sh` | Alias and shell function injection; profile activation depends on this |

### HIGH FRAGILITY — require Orchestrator approval + extended risk brief + integration tests

| File | Reason |
|---|---|
| `github-api.sh` | GitHub API integration; side effects on remote |
| `github-sync-state.sh` | Sync state database; data integrity risk |
| `sync-pull.sh` | Two-way sync; data loss risk |
| `sync-push.sh` | Two-way sync; data loss risk |
| `sync-bidirectional.sh` | Two-way sync; data loss risk |
| `field-mapper.sh` | Sync correctness layer |
| `sync-detector.sh` | Sync correctness layer |
| `conflict-resolver.sh` | Sync correctness layer |
| `annotation-sync.sh` | Sync correctness layer |

### Standard — normal change process applies

`config-loader.sh`, `config-utils.sh`, `core-utils.sh`, `delete-utils.sh`, `dependency-installer.sh`, `error-handler.sh`, `export-utils.sh`, `installer-utils.sh`, `logging.sh`, `profile-manager.sh`, `profile-stats.sh`, `shortcode-registry.sh`, `taskwarrior-api.sh`, `bugwarrior-integration.sh`

---

## Library Map

### Foundation

| File | Purpose | Key Functions |
|---|---|---|
| `core-utils.sh` | Logging, validation, profile checks, service discovery | `log_info/warning/error/success`, `validate_profile_name`, `profile_exists`, `require_active_profile`, `discover_services`, `die` |
| `logging.sh` | Sync operation and error log management | `init_logging`, `log_sync_operation`, `log_error`, `log_operation_start/end`, `rotate_logs` |
| `profile-manager.sh` | Profile directory creation, taskrc, timewarrior hook, journals, ledgers | `create_profile_directories`, `create_taskrc`, `install_timewarrior_hook`, `add_journal_to_profile`, `create_ledger_config` |
| `config-loader.sh` | YAML config loading | — |
| `config-utils.sh` | Config utilities | — |
| `taskwarrior-api.sh` | TaskWarrior wrapper functions | — |
| `error-handler.sh` | Structured error handling | — |
| `shortcode-registry.sh` | Shortcode lookup | — |

### Shell Integration (SERIALIZED)

| File | Purpose | Key Functions |
|---|---|---|
| `shell-integration.sh` | Shell alias injection, profile activation, bare commands | `create_profile_aliases`, `remove_profile_aliases`, `use_task_profile`, `get_ww_rc_files`, `ww_resolve_scope`, `ensure_global_workspace`, `j`, `l`, `list`, `task`, `timew`, `profile`, `profiles`, `journals` |

### GitHub Sync Engine (ALL HIGH FRAGILITY)

| File | Purpose | Key Functions |
|---|---|---|
| `github-api.sh` | `gh` CLI wrapper for GitHub API calls | `check_gh_cli`, `github_get_issue`, `github_update_issue`, `github_update_labels`, `github_add_comment`, `github_ensure_label` |
| `github-sync-state.sh` | SQLite-backed sync state database | `init_state_database`, `get_sync_state`, `save_sync_state`, `is_task_synced`, `get_all_synced_tasks`, `remove_sync_state` |
| `sync-detector.sh` | Change detection between TW and GitHub | `detect_task_changes`, `detect_github_changes`, `determine_sync_action`, `detect_new_annotations`, `detect_new_comments`, `has_conflicts` |
| `field-mapper.sh` | Data transformation TW ↔ GitHub | `map_status_to_github`, `map_github_to_status`, `map_priority_to_label`, `map_labels_to_priority`, `map_tags_to_labels`, `map_labels_to_tags`, `filter_system_tags`, `sanitize_label_name` |
| `conflict-resolver.sh` | Last-write-wins conflict resolution | `compare_timestamps`, `resolve_conflict_last_write_wins`, `log_conflict_resolution` |
| `annotation-sync.sh` | TW annotation ↔ GitHub comment sync | `sync_annotations_to_comments`, `sync_comments_to_annotations`, `sync_annotations_bidirectional` |
| `sync-pull.sh` | Pull GitHub → TaskWarrior | `sync_pull_issue`, `sync_pull_all` |
| `sync-push.sh` | Push TaskWarrior → GitHub | `sync_push_task`, `sync_push_all` |
| `sync-bidirectional.sh` | Orchestrates both directions | `sync_task_bidirectional`, `sync_all_tasks` |

---

## Coding Standards

- `#!/usr/bin/env bash` header on every file
- All function names in `snake_case`
- All local variables declared with `local`
- All variable expansions quoted: `"$var"`, `"${array[@]}"`
- Absolute paths only — `$WORKWARRIOR_BASE/...`, never relative
- Use `lib/logging.sh` functions — never raw `echo` for user-facing messages
- Exit codes: 0 = success, 1 = user error, 2 = system/internal error
- Error propagation via `return` codes, not `exit` or traps

---

## Sync Engine Dependency Chain

```
github-sync.sh (service)
  └── sync-bidirectional.sh
        ├── sync-pull.sh
        │     ├── github-api.sh
        │     ├── field-mapper.sh
        │     ├── annotation-sync.sh
        │     └── github-sync-state.sh
        ├── sync-push.sh
        │     ├── github-api.sh
        │     ├── field-mapper.sh
        │     ├── annotation-sync.sh
        │     └── github-sync-state.sh
        └── sync-detector.sh
              ├── field-mapper.sh
              └── github-sync-state.sh
```

Changes to any node propagate risk upward. When modifying a leaf, check all callers.

---

## Testing Requirements for lib/ Changes

Any change to `lib/` requires the full BATS suite:

```bash
bats tests/
```

GitHub sync changes additionally require:

```bash
bats tests/test-github-sync.bats
bats tests/test-sync-state.bats
bash tests/run-integration-tests.sh   # requires gh auth + test profile
```

See `tests/CLAUDE.md` for full test matrix.
