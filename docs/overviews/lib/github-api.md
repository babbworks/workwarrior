# lib/github-api.sh

**Type:** Sourced bash library  
**Fragility:** HIGH — direct GitHub REST API calls; network side effects; rate limiting

---

## Role

All GitHub API operations via the `gh` CLI. Every function that touches the GitHub API goes through this file. No direct `curl` calls — all API access is via `gh issue`, `gh label`, `gh api`.

---

## Pre-flight

**`check_gh_cli()`**  
Validates gh CLI is installed and authenticated before any API call.  
Returns: `0` success, `2` not-installed `[not-installed]`, `3` not-authenticated `[not-authenticated]`  
Error messages include the category tag in brackets for programmatic parsing.

---

## Issue Operations

**`github_get_issue(repo, issue_number)`**  
Fetches full issue JSON: number, title, state, stateReason, labels, comments, createdAt, updatedAt, closedAt, url, author.  
Error categories: `[rate-limited]` (HTTP 429), `[not-found]` (deleted issue), `[permission-denied]`.

**`github_update_issue(repo, issue_number, title, state)`**  
Updates issue title and/or state (OPEN/CLOSED). Either field is optional.

**`github_update_labels(repo, issue_number, add_labels, remove_labels)`**  
Adds and/or removes comma-separated label lists atomically.

**`github_add_comment(repo, issue_number, body)`**  
Adds a comment. Returns the comment ID extracted from the response URL.

**`github_ensure_label(repo, label_name)`**  
Creates a label if it doesn't exist. Handles race conditions (label created between check and create). Default color: `#0366d6`.

---

## Error Handling

All functions capture stderr from `gh` commands and classify errors:
- HTTP 429 / "secondary rate limit" → `[rate-limited]` with retry-after advice
- "Could not resolve to an Issue" → `[not-found]`
- "permission" → `[permission-denied]`
- Other → generic error with raw gh output

---

## Rate Limiting

No automatic retry logic — callers receive `[rate-limited]` and must decide whether to retry. Check remaining quota: `gh api rate_limit`.

---

## Design Constraints

- Never call `gh` directly outside this file — all GitHub API access goes through these functions
- All functions return non-zero on any API failure — callers must check return codes
- `check_gh_cli()` must be called before any API operation (enforced by `sync_preflight()` in `github-sync.sh`)

## Changelog

- 2026-04-10 — Initial version
