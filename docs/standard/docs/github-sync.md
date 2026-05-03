---
layout: doc
title: GitHub Sync
eyebrow: Documentation
description: Two complementary sync engines — Bugwarrior for pulling issues, ww github-sync for bidirectional task↔issue sync.
permalink: /docs/github-sync
doc_section: features
doc_order: 3
---

Workwarrior ships two GitHub sync engines. They're complementary and work simultaneously.

**Bugwarrior** — one-way pull from 20+ services into TaskWarrior.  
**ww github-sync** — two-way bidirectional sync between individual tasks and GitHub issues.

## Bugwarrior: Pull Everything

```bash
ww issues custom          # Configure services interactively (per-profile)
i pull                    # Pull from all configured services
i status                  # Show what was pulled
```

Supported services: GitHub, GitLab, Jira, Trello, Bitbucket, Taiga, Pagure, and 13+ more.

Tasks created by Bugwarrior carry UDAs stamped `[github]` in the source registry: `githubissue`, `githuburl`, `githubrepo`, `githubauthor`.

## ww github-sync: Two-Way on Selected Tasks

```bash
ww issues enable <task_id> <issue_num> <org/repo>    # Link task to GitHub issue
ww issues disable <task_id>                          # Unlink
ww issues sync                                        # Two-way sync all linked tasks
ww issues push                                        # Push local changes to GitHub only
ww issues pull                                        # Pull GitHub changes only
ww issues status                                      # Show sync state for all linked tasks
```

### Field Mapping

**Bidirectional:**

| TaskWarrior | GitHub Issue |
|-------------|-------------|
| `description` | title |
| `status` | state (pending/started → OPEN, completed/deleted → CLOSED) |
| `priority` | labels (H → priority:high, M → medium, L → low) |
| `tags` | labels |
| `annotations` | comments (prefixed `[tw]`) |

**Pull-only (GitHub → TaskWarrior):**

| GitHub | TaskWarrior UDA |
|--------|-----------------|
| Issue number | `githubissue` |
| Issue URL | `githuburl` |
| Repository | `githubrepo` |
| Author | `githubauthor` |

## Conflict Resolution

Last-write-wins with a configurable conflict window (default: 60 seconds).

If both sides changed within the window: sync reports the conflict rather than overwriting. Shows both values with timestamps. User resolves manually.

Outside the window: more recently modified side wins.

## Authentication

Uses GitHub CLI (`gh`) for authentication. Token stored via the oracle pattern — never written to disk:

```
github.token = @oracle:eval:gh auth token
```

Prerequisites:
```bash
brew install gh   # or equivalent
gh auth login
gh auth status
```

## Using Both Together

1. `ww issues custom` — configure Bugwarrior for all your services
2. `i pull` — get all open issues as TaskWarrior tasks
3. `ww issues enable <task> <issue#> <org/repo>` — link the tasks you're actively working
4. Work normally. `i pull` refreshes. `ww issues sync` keeps linked tasks current.

The two engines don't interfere — Bugwarrior stamps its tasks with `[github]` UDA badges; github-sync manages its own state file separately.

## Troubleshooting

**Orphaned tasks:** If a linked GitHub issue is deleted, sync logs a warning and skips. Run `ww issues disable <uuid>` to clean up the link.

**UDA write failures:** Logged as warnings, not silent. `ww issues status` shows failed UDA writes.

**Auth errors:** Run `gh auth status` to verify authentication. `gh auth refresh` to renew.
