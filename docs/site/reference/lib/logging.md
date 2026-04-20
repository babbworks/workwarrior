# lib/logging.sh

**Type:** Sourced bash library  
**Used by:** All service scripts and lib files that produce user-facing output

---

## Role

Two distinct logging systems in one file: (1) terminal output functions for user-facing messages, (2) file-based sync operation logging for the GitHub sync engine.

---

## Terminal Output Functions

All output goes to stderr to keep stdout clean for data (JSON, lists).

| Function | Output | Use |
|---|---|---|
| `log_info(msg)` | `ℹ msg` | Informational, non-critical |
| `log_success(msg)` | `✓ msg` | Operation completed successfully |
| `log_warning(msg)` | `⚠ msg` | Non-fatal issue, operation continues |
| `log_error(msg)` | `✗ msg` | Fatal error, caller should exit |
| `log_step(msg)` | `» msg` | Progress indicator for multi-step operations |
| `log_deprecation(msg)` | `deprecated: msg` | Legacy syntax nudge |

**Rule:** Never use raw `echo` for user-facing messages in `lib/` or `services/`. Always use these functions. Raw `echo` in service scripts is a Gate B violation.

---

## Sync File Logging

Used exclusively by the GitHub sync engine. Writes structured log entries to per-profile log files.

**`init_logging()`**  
Creates log directory at `$WORKWARRIOR_BASE/.task/github-sync/`. Returns 1 (non-fatal) if creation fails.

**`get_sync_log_path()`** / **`get_error_log_path()`**  
Returns paths to `sync.log` and `errors.log` in the profile's github-sync directory.

**`log_sync_operation(operation, task_uuid, details)`**  
Appends timestamped entry to `sync.log`.

**`log_conflict_resolution(task_uuid, resolution, details)`**  
Appends conflict resolution decision to `sync.log`.

**`log_operation_start(operation)` / `log_operation_end(operation, status)`**  
Bracket log entries for multi-step operations.

**`rotate_logs()`**  
Rotates `sync.log` when it exceeds 1MB. Keeps one `.1` backup.

**`get_recent_operations(n)` / `get_recent_errors(n)`**  
Returns last N lines from the respective log files.

**`show_sync_stats()`**  
Parses `sync.log` and outputs operation counts by type.

---

## Design Notes

- Sync log files are in `.gitignore` — never committed
- Terminal functions write to stderr; sync functions write to files
- `init_logging()` failure is non-fatal — sync continues without logging rather than aborting

## Changelog

- 2026-04-10 — Initial version
