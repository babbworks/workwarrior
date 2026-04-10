# lib/error-handler.sh — Cross-Cutting: GitHub Error Classification

**Type:** Sourced bash library
**Used by:** `lib/sync-pull.sh`, `lib/sync-push.sh`, `services/custom/github-sync.sh`
**Classification:** Cross-cutting — GitHub error handling used across the entire sync engine

---

## Role

Classifies GitHub API errors from `gh` CLI output and routes them to appropriate recovery handlers. Separates error detection (in `github-api.sh`) from error recovery (here). Provides `sync_with_error_handling()` as a wrapper that adds retry and recovery logic around any sync operation.

---

## Error Parsers

**`parse_github_error(gh_output)`**
Reads raw `gh` CLI stderr/stdout and returns a structured error type:
- `rate_limited` — HTTP 429 or "secondary rate limit"
- `not_found` — "Could not resolve to an Issue"
- `permission_denied` — "permission" in error text
- `network_error` — connection refused, timeout
- `auth_error` — "not authenticated", "token"
- `unknown` — anything else

---

## Error Handlers

**`handle_title_error(task_uuid, error_type)`** — Handles failures updating issue title. For `rate_limited`: logs and returns retry signal. For `permission_denied`: logs and marks task as sync-disabled.

**`handle_state_error(task_uuid, error_type)`** — Handles failures updating issue state (open/closed).

**`handle_label_error(task_uuid, error_type)`** — Handles label update failures. Label errors are non-fatal — logged as warnings, sync continues.

**`handle_permission_error(repo, operation)`** — Handles permission denied errors. Logs the specific repo and operation. Suggests `gh auth refresh` or checking repo permissions.

**`handle_rate_limit_error(retry_after)`** — Logs rate limit hit with retry-after seconds. Does not sleep — returns a signal to the caller to decide whether to retry or abort.

---

## Wrapper

**`sync_with_error_handling(operation_fn, task_uuid, ...args)`**
Wraps any sync operation function with error classification and recovery:
1. Calls `operation_fn` with args
2. On failure, calls `parse_github_error()` on captured output
3. Routes to appropriate handler
4. Returns: `success`, `retry`, `skip`, or `abort`

Used by `sync_push_task()` and `sync_pull_issue()` for the outer error boundary.
