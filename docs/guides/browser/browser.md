# Browser UI

`ww browser` launches a locally-served web interface. No cloud, no accounts, no npm, no external dependencies — Python 3 stdlib only.

## Starting and Stopping

```bash
ww browser                     # Start on port 7777, open browser
ww browser --port 9090         # Custom port
ww browser --no-open           # Start without opening browser
ww browser stop                # Stop the server
ww browser status              # Show running state
```

## Panels

The UI has a dark terminal aesthetic with a collapsible sidebar. Panels include:

**Data Panels**
- Tasks — full task list with inline editing, UDA display, start/stop/done buttons, add form, annotations
- Time — today's total, weekly breakdown, recent intervals, start/stop controls
- Journals — entry list with expand/collapse, new entry form, multi-journal selector
- Ledgers — account balances, recent transactions, income statement, balance sheet, new transaction form

**Command Panels**
- CMD — unified command input accepting both `ww` commands and natural language
- CTRL — AI mode toggle (off / local-only / local+remote), prompt settings, UI config

**Service Panels**
- Models — LLM provider and model registry
- Groups — profile group management
- Sync — GitHub sync dashboard
- Questions — template browser
- Profile — profile info and resource management

**Weapons Bar**
- Sidebar weapons row with icons for Gun, Sword, and planned weapons

## CMD Input

The CMD panel accepts two kinds of input:

**Direct commands** — any `ww` subcommand:
```
profile list
journal add meeting-notes
ctrl ai-status
```

**Natural language** — translated via heuristic engine or AI:
```
add a task to review the budget due friday
start tracking time on code review
show my profiles
finish task 5 and stop tracking
```

A route indicator shows how each command was processed: ⚡ AI or ⚙ heuristic.

## Multi-Resource Support

When a profile has multiple named journals, ledgers, or time tracking instances, the UI shows a dropdown selector. Switching resources updates the panel data immediately.

## Real-Time Updates

The server uses Server-Sent Events (SSE) to push profile changes to the browser. When you switch profiles via the CLI, the browser updates automatically.

## API Endpoints

The server exposes a REST API for programmatic access:

| Method | Path | Description |
|--------|------|-------------|
| GET | /health | Liveness check with profile and version |
| GET | /data/tasks | Pending tasks for active profile |
| GET | /data/time | Time intervals and totals |
| GET | /data/journal | Recent journal entries |
| GET | /data/ledger | Account balances and transactions |
| GET | /data/ctrl | AI settings and resolved provider |
| POST | /cmd | Execute a ww subcommand |
| POST | /cmd/ai | Natural language command translation |
| POST | /action | Task/journal/ledger mutations |
| POST | /profile | Switch active profile |
| POST | /resource | Switch active named resource |
| GET | /events | SSE stream |
