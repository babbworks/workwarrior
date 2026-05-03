---
layout: doc
title: Browser UI
eyebrow: Documentation
description: The locally-served web interface — 15+ panels, SSE real-time updates, no npm, Python 3 stdlib only.
permalink: /docs/browser-ui
doc_section: features
doc_order: 1
---

## Starting and Stopping

```bash
ww browser                     # Start on port 7777, open browser
ww browser --port 9090         # Custom port
ww browser --no-open           # Start without opening
ww browser stop                # Stop server
ww browser status              # Show running state
```

The server starts in under a second. No npm, no build step, no external dependencies — Python 3 stdlib only.

## Panels

### Data Panels

**Tasks** — Full task list with inline editing. Displays all UDAs defined in the active profile. Actions: start/stop/done buttons, add task form, annotation management.

**Time** — Today's total, weekly breakdown, recent intervals, start/stop controls.

**Journals** — Entry list with expand/collapse. Multi-journal selector dropdown when the profile has multiple named journals. New entry form.

**Ledgers** — Account balances, recent transactions, income statement, balance sheet. New transaction form. Multi-ledger selector.

### Command Panels

**CMD** — Unified command input accepting both direct `ww` commands and natural language. Route indicator: `⚡` AI or `⚙` heuristic.

**CTRL** — AI mode toggle (off / local-only / local+remote). Prompt settings. UI configuration.

### Service Panels

**Models** — LLM provider and model registry. Add providers, set defaults.

**Groups** — Profile group management.

**Sync** — GitHub sync dashboard. Shows linked tasks, last sync times, conflict status.

**Questions** — Template browser. Run structured capture workflows.

**Profile** — Active profile info. Resource lists. Profile switching.

**Weapons bar** — Sidebar icons for Gun, Sword, Next, Schedule. Clicking opens the weapon's panel.

## CMD Input

The CMD panel accepts two kinds of input:

**Direct commands** — any `ww` subcommand:
```
profile list
journal add meeting-notes
ctrl ai-status
issues sync
```

**Natural language** — translated via heuristic engine (627 rules) or AI fallback:
```
add a task to review the budget due friday
start tracking time on code review
finish task 5 and stop tracking
show my profiles
```

Compound commands (joined by "and", "then", "also", "plus") are split and matched independently.

## Real-Time Updates

The server uses Server-Sent Events (SSE) to push profile changes to the browser. Switch profiles via the CLI — the browser updates automatically. Data panels refresh when commands complete.

## Multi-Resource Support

When a profile has multiple named journals, ledgers, or time tracking instances, the relevant panel shows a dropdown selector. Switching updates the panel immediately without page reload.

## API Endpoints

The server exposes a REST API:

| Method | Path | Description |
|--------|------|-------------|
| GET | /health | Liveness check |
| GET | /data/tasks | Active profile tasks |
| GET | /data/time | Time intervals and totals |
| GET | /data/journal | Recent journal entries |
| GET | /data/ledger | Account balances and transactions |
| GET | /data/ctrl | AI settings |
| POST | /cmd | Execute a ww subcommand |
| GET | /events | SSE stream |

## Security

All `POST /cmd` requests are validated against an `ALLOWED_SUBCOMMANDS` frozenset. The first token must be a known ww subcommand. No `sh -c`, no eval. Unknown subcommands return HTTP 400.
