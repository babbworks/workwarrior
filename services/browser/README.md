# services/browser — Workwarrior Browser Service

The browser service runs a lightweight Python 3 HTTP server that exposes Workwarrior data to a local web UI. It provides a `/health` endpoint for liveness checks, a `/events` endpoint for Server-Sent Events (SSE) live updates, a `/cmd` endpoint to execute `ww` subcommands from the browser, a `/profile` endpoint to switch the active profile, and a `/resource` endpoint to switch the active journal, ledger, task list, or TimeWarrior instance within a profile session.

## Usage

```sh
ww browser                        # start on default port 7777, open browser tab
ww browser --port 8080            # start on port 8080
ww browser --no-open              # start without opening a browser tab
ww browser stop                   # stop the running server
ww browser status                 # print running/not-running + port + PID
ww browser export                 # generate a self-contained offline HTML snapshot
```

## Endpoints

| Method | Path                    | Description                                              |
|--------|-------------------------|----------------------------------------------------------|
| GET    | /health                 | JSON liveness check with active profile and version      |
| GET    | /events                 | SSE stream: connected, ping (15s), profile-change events |
| POST   | /cmd                    | Run a `ww` subcommand; body: `{"cmd":"<subcommand>"}` |
| POST   | /cmd/ai                 | Translate natural language to ww commands using configured AI runtime |
| POST   | /profile                | Switch active profile; body: `{"profile":"<name>"}` |
| POST   | /resource               | Switch active resource; body: `{"kind":"journals","name":"<key>"}` |
| GET    | /data/tasks             | Pending + active tasks for active profile/tasklist |
| GET    | /data/time              | TimeWarrior intervals and totals for active timew instance |
| GET    | /data/journal           | Recent journal entries for active journal |
| GET    | /data/ledger            | Account balances and recent transactions for active ledger |
| GET    | /data/next              | Recommended next task (`task next export`) |
| GET    | /data/schedule          | Schedule service status |
| GET    | /data/ctrl              | Effective CTRL/AI settings + resolved active provider/model |
| GET    | /data/profile-resources | All named resources + current selections for active profile |
| GET    | /data/all               | Aggregate snapshot for static export |
| GET    | /data/community/list    | Communities + entry counts (global `services/community/community.sh`) |
| GET    | /data/community/<name> | Entries for one community; optional `?view=unified|journal|tasks|comments` (hint for UI) |
| POST   | /action                 | Task/journal/ledger mutation; `community_add` snapshots a task or journal line into a global community |
| GET    | /                       | Web UI (index.html) |

## Multi-resource support

Each profile can have multiple named journals, ledgers, task lists, and TimeWarrior instances. The server tracks the active selection per session (reset on profile switch). The UI shows a dropdown selector when more than one option exists for the current section. This anticipates future ww support for multiple task lists and TimeWarrior instances per profile.
