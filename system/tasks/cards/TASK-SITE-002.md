## TASK-SITE-002: Implement `ww browser` server scaffolding — Wave 1 of TASK-SITE-001

Goal:                 Stand up the browser service skeleton: Python3 HTTP server with SSE
                      live-data endpoint, POST /cmd action endpoint, profile-switch endpoint,
                      and `ww browser` / `ww browser stop` / `ww browser status` wired into bin/ww.
                      No UI rendering in this wave — server infrastructure only.

Dependency:           TASK-SITE-001 (design card, accepted)

---

Acceptance criteria:

  1. `ww browser` starts a Python3 HTTP server on port 7777 (default), prints
     "Workwarrior browser running at http://localhost:7777 — Ctrl-C or 'ww browser stop' to quit"
     and opens the URL in the default browser (macOS: open; Linux: xdg-open).

  2. `ww browser --port N` starts the server on port N instead of 7777.

  3. `ww browser --no-open` starts the server without launching the browser.

  4. `ww browser stop` sends a stop signal to a running server and confirms shutdown.
     If no server is running, prints a clear message and exits 0.

  5. `ww browser status` prints one of:
       "running on http://localhost:<port>  (pid <N>)"
       "not running"
     Exit code 0 in both cases.

  6. GET /health returns HTTP 200 and JSON: {"status":"ok","profile":"<active>","version":"1.0.0"}

  7. GET /events returns a valid text/event-stream (SSE) response that:
     - Sends an initial "connected" event immediately
     - Sends a "ping" event every 15 seconds to keep the connection alive
     - Sends a "profile" event when the active profile changes

  8. POST /cmd with JSON body {"cmd": "<ww subcommand and args>"} executes the command
     against the active profile and returns JSON:
       {"ok": true,  "output": "<stdout>", "exit_code": 0}
       {"ok": false, "output": "<stderr>", "exit_code": N}
     Only ww subcommands are accepted. Bare shell commands are rejected with 400.

  9. POST /profile with JSON body {"profile": "<name>"} switches the active profile
     server-side (updates WW_ACTIVE_PROFILE state file), returns 200 + JSON:
       {"ok": true, "profile": "<name>"}
     If profile does not exist, returns 400 + {"ok": false, "error": "profile not found"}.

  10. Server PID is written to $WW_BASE/.state/browser.pid on start and removed on stop.
      Port is written to $WW_BASE/.state/browser.port.

  11. Port-in-use detection: if port is taken, prints a clear error with a suggestion
      to use --port N, exits 1.

  12. `ww browser --help` prints correct usage block including all subcommands and flags.

  13. `bats tests/test-browser.sh` passes: covers start, stop, status, health endpoint,
      /cmd endpoint, /profile endpoint, port conflict detection.

  14. `ww browser` and subcommands appear in `ww help` output.

---

Write scope:          /Users/mp/ww/services/browser/                  (new — all files within)
                      /Users/mp/ww/bin/ww                             (add cmd_browser + dispatch)
                      /Users/mp/ww/tests/test-browser.sh              (new BATS suite)
                      /Users/mp/ww/system/config/command-syntax.yaml  (add browser domain)

---

Implementation notes:

  services/browser/ layout:
    browser.sh          — main entry point, sourced by bin/ww cmd_browser()
                          OR called directly as a service executable
    server.py           — Python3 HTTP server (stdlib only: http.server, threading,
                          subprocess, json, os, signal)
    README.md           — service README per services contract

  server.py design:
    - BaseHTTPRequestHandler subclass
    - Threading: use ThreadingHTTPServer (Python 3.7+) so SSE connections don't
      block POST /cmd requests
    - SSE: keep a thread-safe list of response objects; broadcast to all on events
    - /cmd allowlist: only passes args to `ww <subcommand>` — never eval, never sh -c
    - Profile switch: write new profile name to $WW_BASE/.state/active_profile,
      broadcast SSE "profile" event to all connected clients
    - Graceful shutdown: handle SIGTERM + SIGINT, remove PID/port state files

  bin/ww additions:
    - cmd_browser() function modeled on cmd_tui() / cmd_mcp() pattern
    - Case entry in main() dispatch table: browser)
    - Usage string entry in show_usage()

  State files (created by server on start, removed on stop):
    $WW_BASE/.state/browser.pid     — PID of running server.py process
    $WW_BASE/.state/browser.port    — port number

  BATS test approach:
    - Start server in background, wait for /health 200, run assertions, stop
    - Use `curl -s` for HTTP assertions
    - Test port conflict by starting two servers on same port

---

Tests required:       bats tests/test-browser.sh
                      bats tests/
                      Manual: ww browser (verify server starts, browser opens)
                      Manual: ww browser stop (verify clean shutdown)
                      Manual: curl http://localhost:7777/health
                      Manual: curl -N http://localhost:7777/events (verify SSE stream)
                      Manual: curl -X POST http://localhost:7777/cmd \
                                -H 'Content-Type: application/json' \
                                -d '{"cmd":"task count"}' (verify JSON response)

Rollback:             rm -rf /Users/mp/ww/services/browser/
                      rm -f /Users/mp/ww/tests/test-browser.sh
                      git checkout /Users/mp/ww/bin/ww
                      git checkout /Users/mp/ww/system/config/command-syntax.yaml

Fragility:            SERIALIZED: bin/ww — confirm no parallel active task touches this file
                      None other — services/browser/ and tests/test-browser.sh are new files

Risk notes:           (Orchestrator) bin/ww is 2225 lines; Builder must read the full
                      cmd_tui() and cmd_mcp() implementations as the model for cmd_browser().
                      Dispatch table entry belongs after the mcp) case (line ~2176).
                      show_usage() must be updated to include browser in the command list.
                      Python3 availability: server.py must fail gracefully with a clear
                      error if python3 is not found (exit 1 + install hint).
                      SSE + concurrent POST requires ThreadingHTTPServer — single-threaded
                      BaseHTTPServer will deadlock when an SSE client holds the connection.
                      (Builder pre-flight) TBD

Status:               complete
