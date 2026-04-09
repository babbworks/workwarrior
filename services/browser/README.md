# services/browser — Workwarrior Browser Service

The browser service runs a lightweight Python 3 HTTP server that exposes Workwarrior data to a local web UI. It provides a `/health` endpoint for liveness checks, a `/events` endpoint for Server-Sent Events (SSE) live updates, a `/cmd` endpoint to execute `ww` subcommands from the browser, and a `/profile` endpoint to switch the active profile. The server writes its PID and port to `$WW_BASE/.state/browser.pid` and `$WW_BASE/.state/browser.port` and removes them on clean shutdown.

## Usage

```sh
ww browser                        # start on default port 7777, open browser tab
ww browser --port 8080            # start on port 8080
ww browser --no-open              # start without opening a browser tab
ww browser stop                   # stop the running server
ww browser status                 # print running/not-running + port + PID
```

## Endpoints

| Method | Path       | Description                                              |
|--------|------------|----------------------------------------------------------|
| GET    | /health    | JSON liveness check with active profile and version      |
| GET    | /events    | SSE stream: connected, ping (15s), profile-change events |
| POST   | /cmd       | Run a `ww` subcommand; body: `{"cmd":"<subcommand ...}"}` |
| POST   | /profile   | Switch active profile; body: `{"profile":"<name>"}` |
| GET    | /          | Placeholder HTML (Wave 2 UI coming soon)                 |
