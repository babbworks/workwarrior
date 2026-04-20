# Services

Everything in Workwarrior is a service. The `ww` dispatcher routes commands to service scripts in `services/<category>/`.

## Service Registry

| Domain | Commands | What it does |
|--------|----------|-------------|
| **profile** | create, list, info, delete, backup, import, restore, uda, urgency, density | Profile lifecycle and configuration |
| **journal** | add, list, remove, rename | Named journal management |
| **ledger** | add, list, remove, rename | Named ledger management |
| **group** | list, create, show, add, remove, delete | Profile groups for batch operations |
| **model** | list, providers, show, add-provider, remove-provider, add-model, set-default, env, check | LLM provider and model registry |
| **ctrl** | status, ai-on, ai-off, ai-status, ai-mode, prompt-ww, prompt-ai | AI mode, prompt settings, UI config |
| **find** | `<term>` with filters | Cross-profile search across tasks, time, journals, ledgers |
| **issues** | sync, push, pull, status, enable, disable, custom, uda | GitHub two-way sync + bugwarrior pull |
| **custom** | journals, ledgers, tasks, times, issues | Interactive configuration wizards |
| **extensions** | taskwarrior list/search/info/refresh | Extension registry for TaskWarrior and TimeWarrior |
| **export** | JSON, CSV, markdown | Profile data export |
| **questions** | list, new, delete, `<template>` | Template-based capture workflows |
| **browser** | start, stop, status, export | Locally-served web UI |
| **remove** | `<profile>`, --keep, --all, --archive-all, --delete-all | Profile removal with scrubbing |
| **shortcut** | list, info, add, remove | Shortcut/alias reference and management |
| **deps** | install, check | Dependency management |
| **compile-heuristics** | --verbose, --digest | Recompile NL→command rules |

## Weapons (via ww command)

| Domain | What it does |
|--------|-------------|
| **gun** | Bulk task series generator |
| **sword** | Task splitting into sequential subtasks |
| **next** | CFS-inspired next-task recommendation |
| **schedule** | Auto-scheduler |
| **mcp** | MCP server for AI agent access to TaskWarrior |
| **tui** | Full-screen terminal UI (taskwarrior-tui) |

## Issue Sync — Two Engines

**Bugwarrior** (one-way pull): pulls issues from GitHub, GitLab, Jira, Trello, and 20+ services into TaskWarrior. Configured per-profile via `ww issues custom`.

**ww github-sync** (two-way): links individual tasks to GitHub issues for bidirectional sync. Handles field mapping, conflict resolution (last-write-wins), annotation↔comment sync, and label encoding for UDA values.

```bash
i pull                             # Pull from all configured services
ww issues sync                     # Two-way sync all linked tasks
ww issues enable <task> <issue#> <org/repo>  # Link a task to an issue
```

## Building New Services

Services are executable scripts in `services/<category>/`. Requirements:
- Responds to `--help` / `-h`
- Uses exit codes: 0 success, 1 user error, 2 system error
- Logs via `lib/logging.sh`
- Does not write to profile directories directly

See `docs/service-development.md` for the full contract and template tiers.
