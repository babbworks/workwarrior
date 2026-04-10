#!/usr/bin/env python3
"""
services/browser/server.py — Workwarrior browser HTTP server

Python 3 stdlib only. ThreadingHTTPServer is required so that SSE connections
(which hold the socket open) do not block concurrent POST /cmd requests.

Endpoints:
  GET  /health        → 200 {"status":"ok","profile":"<active>","version":"1.0.0"}
  GET  /events        → text/event-stream SSE (connected + ping every 15s + profile events)
  POST /cmd           → run ww subcommand, return {"ok":bool,"output":"...","exit_code":N}
  POST /profile       → switch active profile, return {"ok":bool,"profile":"..."} or 400
  GET  /data/tasks    → pending task list for active profile
  GET  /data/time     → time tracking intervals and totals for active profile
  GET  /data/journal  → recent journal entries for active profile
  GET  /data/ledger   → account balances and recent transactions for active profile
  POST /action        → task mutation (start/stop/done/add/annotate/journal_add/ledger_add)
  GET  /              → minimal placeholder HTML

State files (written on start, removed on clean shutdown):
  $WW_BASE/.state/browser.pid
  $WW_BASE/.state/browser.port

CLI:
  python3 server.py [--port N] [--no-open] [--ww-base PATH]
"""

import argparse
import http.server
import json
import os
import queue
import signal
import socket
import subprocess
import sys
import threading
import time


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

VERSION = "1.0.0"

# Subcommands that POST /cmd is permitted to invoke.
# This is the security boundary — bare shell commands are rejected with 400.
ALLOWED_SUBCOMMANDS = frozenset([
    "profile", "profiles", "service", "services",
    "group", "groups", "model", "models",
    "journal", "journals", "ledger", "ledgers",
    "tui", "mcp", "issues", "custom", "shortcut",
    "export", "find", "extensions", "deps",
    "version", "help", "browser",
    # task is a common alias people may use in tests
    "task",
])


# ---------------------------------------------------------------------------
# Global server state
# ---------------------------------------------------------------------------

class ServerState:
    """Mutable runtime state shared between the HTTP handler and the ping thread."""

    def __init__(self, ww_base: str):
        self.ww_base = ww_base
        self.lock = threading.Lock()
        # Each connected SSE client gets a Queue; handler reads from it.
        self.sse_clients: list[queue.Queue] = []
        self._shutdown_event = threading.Event()

    # -- Profile helpers -----------------------------------------------------

    @property
    def active_profile_path(self) -> str:
        return os.path.join(self.ww_base, ".state", "active_profile")

    def get_active_profile(self) -> str:
        """Return the name of the currently active profile, or empty string."""
        try:
            with open(self.active_profile_path, "r") as fh:
                return fh.read().strip()
        except OSError:
            return ""

    def get_profile_paths(self) -> dict:
        """
        Return a dict of absolute paths for the active profile's tool data.

        Resolves journal and ledger paths from their respective YAML config
        files when present. Falls back to convention-based defaults.
        Returns an empty dict when no profile is active.
        """
        profile = self.get_active_profile()
        if not profile:
            return {}
        base = os.path.join(self.ww_base, "profiles", profile)

        # -- Journal path ------------------------------------------------
        journal_file = os.path.join(base, "journals", f"{profile}.txt")
        jrnl_yaml = os.path.join(base, "jrnl.yaml")
        if os.path.isfile(jrnl_yaml):
            try:
                content = open(jrnl_yaml).read()
                import re as _re
                m = _re.search(r'default:\s*(.+)', content)
                if m:
                    journal_file = m.group(1).strip()
            except OSError:
                pass

        # -- Ledger path -------------------------------------------------
        ledger_file = os.path.join(base, "ledgers", f"{profile}.journal")
        ledgers_yaml = os.path.join(base, "ledgers.yaml")
        if os.path.isfile(ledgers_yaml):
            try:
                content = open(ledgers_yaml).read()
                import re as _re
                m = _re.search(r'default:\s*(.+)', content)
                if m:
                    ledger_file = m.group(1).strip()
            except OSError:
                pass

        return {
            "taskrc":        os.path.join(base, ".taskrc"),
            "taskdata":      os.path.join(base, ".task"),
            "timewarriordb": os.path.join(base, ".timewarrior"),
            "journal_file":  journal_file,
            "ledger_file":   ledger_file,
        }

    def set_active_profile(self, name: str) -> bool:
        """
        Write profile name to state file.
        Returns True if the profile directory exists, False otherwise.
        """
        profile_dir = os.path.join(self.ww_base, "profiles", name)
        if not os.path.isdir(profile_dir):
            return False
        state_dir = os.path.join(self.ww_base, ".state")
        os.makedirs(state_dir, exist_ok=True)
        with open(self.active_profile_path, "w") as fh:
            fh.write(name + "\n")
        return True

    # -- SSE broadcast -------------------------------------------------------

    def broadcast(self, event: str, data: str) -> None:
        """Enqueue an SSE event to all connected clients."""
        message = f"event: {event}\ndata: {data}\n\n"
        with self.lock:
            dead: list[queue.Queue] = []
            for q in self.sse_clients:
                try:
                    q.put_nowait(message)
                except queue.Full:
                    dead.append(q)
            for q in dead:
                self.sse_clients.remove(q)

    def add_sse_client(self, q: queue.Queue) -> None:
        with self.lock:
            self.sse_clients.append(q)

    def remove_sse_client(self, q: queue.Queue) -> None:
        with self.lock:
            if q in self.sse_clients:
                self.sse_clients.remove(q)

    # -- Shutdown ------------------------------------------------------------

    def request_shutdown(self) -> None:
        self._shutdown_event.set()

    def shutdown_requested(self) -> bool:
        return self._shutdown_event.is_set()


# ---------------------------------------------------------------------------
# Ping thread: keeps SSE connections alive and broadcasts profile changes
# ---------------------------------------------------------------------------

def _ping_thread(state: ServerState) -> None:
    """
    Runs in a daemon thread. Sends a 'ping' SSE event every 15 seconds and
    detects profile changes (broadcasting a 'profile' event when they occur).
    """
    last_profile = state.get_active_profile()
    while not state.shutdown_requested():
        # Sleep in short increments so we can notice shutdown quickly
        for _ in range(150):  # 150 × 0.1s = 15 seconds
            if state.shutdown_requested():
                return
            time.sleep(0.1)

        current_profile = state.get_active_profile()
        if current_profile != last_profile:
            last_profile = current_profile
            state.broadcast("profile", json.dumps({"profile": current_profile}))

        state.broadcast("ping", json.dumps({"ts": int(time.time())}))


# ---------------------------------------------------------------------------
# TimeWarrior timestamp helper
# ---------------------------------------------------------------------------

def _parse_timew_ts(ts_str: str) -> float:
    """Parse a TimeWarrior UTC timestamp string like '20260403T090012Z' to Unix time."""
    import calendar
    t = time.strptime(ts_str, "%Y%m%dT%H%M%SZ")
    return float(calendar.timegm(t))


# ---------------------------------------------------------------------------
# HTTP request handler
# ---------------------------------------------------------------------------

def make_handler(state: ServerState, ww_bin: str):
    """
    Return a handler class that closes over the ServerState and ww binary path.
    Using a factory avoids global variables while still working with the
    http.server BaseHTTPRequestHandler class model.
    """

    class Handler(http.server.BaseHTTPRequestHandler):
        """Route all inbound HTTP requests."""

        # Path to the static assets directory (index.html, app.js, style.css).
        STATIC_DIR: str = os.path.join(
            os.path.dirname(os.path.abspath(__file__)), "static"
        )

        # Suppress default per-request log lines; replace with nothing so
        # tests can capture output without noise.
        def log_message(self, fmt, *args):  # type: ignore[override]
            pass

        # -- Routing ---------------------------------------------------------

        def do_GET(self) -> None:  # noqa: N802
            if self.path == "/health":
                self._handle_health()
            elif self.path == "/events":
                self._handle_events()
            elif self.path == "/":
                self._handle_index()
            elif self.path == "/app.js":
                self._serve_static_file(
                    os.path.join(self.STATIC_DIR, "app.js"),
                    "application/javascript",
                )
            elif self.path == "/style.css":
                self._serve_static_file(
                    os.path.join(self.STATIC_DIR, "style.css"),
                    "text/css",
                )
            elif self.path == "/data/tasks":
                self._handle_data_tasks()
            elif self.path == "/data/time":
                self._handle_data_time()
            elif self.path == "/data/journal":
                self._handle_data_journal()
            elif self.path == "/data/ledger":
                self._handle_data_ledger()
            else:
                self._send_json(404, {"error": "not found"})

        def do_POST(self) -> None:  # noqa: N802
            if self.path == "/cmd":
                self._handle_cmd()
            elif self.path == "/profile":
                self._handle_profile()
            elif self.path == "/action":
                self._handle_action()
            else:
                self._send_json(404, {"error": "not found"})

        # -- GET /health -----------------------------------------------------

        def _handle_health(self) -> None:
            body = {
                "status": "ok",
                "profile": state.get_active_profile(),
                "version": VERSION,
            }
            self._send_json(200, body)

        # -- GET / -----------------------------------------------------------

        def _handle_index(self) -> None:
            self._serve_static_file(
                os.path.join(self.STATIC_DIR, "index.html"),
                "text/html",
            )

        def _serve_static_file(self, path: str, content_type: str) -> None:
            """Read a static file from disk and write it to the response."""
            try:
                with open(path, "rb") as fh:
                    data = fh.read()
                self.send_response(200)
                self.send_header("Content-Type", content_type + "; charset=utf-8")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            except OSError:
                self._send_json(404, {"error": "not found"})

        # -- GET /events (SSE) -----------------------------------------------

        def _handle_events(self) -> None:
            """
            Server-Sent Events endpoint.

            Each connection gets its own Queue. The ping thread enqueues
            messages; this handler dequeues and writes them. The connection
            stays open until the client disconnects or the server shuts down.

            ThreadingHTTPServer ensures this long-lived handler does not block
            other request threads.
            """
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "keep-alive")
            self.send_header("X-Accel-Buffering", "no")
            self.end_headers()

            q: queue.Queue = queue.Queue(maxsize=100)
            state.add_sse_client(q)

            # Send the initial 'connected' event immediately
            try:
                connected_msg = (
                    "event: connected\n"
                    f"data: {json.dumps({'profile': state.get_active_profile()})}\n\n"
                )
                self.wfile.write(connected_msg.encode("utf-8"))
                self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError, OSError):
                state.remove_sse_client(q)
                return

            # Stream subsequent events until disconnect or shutdown
            try:
                while not state.shutdown_requested():
                    try:
                        message = q.get(timeout=1.0)
                        self.wfile.write(message.encode("utf-8"))
                        self.wfile.flush()
                    except queue.Empty:
                        continue
            except (BrokenPipeError, ConnectionResetError, OSError):
                pass
            finally:
                state.remove_sse_client(q)

        # -- POST /cmd -------------------------------------------------------

        def _handle_cmd(self) -> None:
            """
            Execute a ww subcommand on behalf of the browser client.

            Security contract:
            - The JSON body must contain {"cmd": "<ww subcommand and args>"}
            - The first token of 'cmd' must be in ALLOWED_SUBCOMMANDS
            - We exec: ww <subcommand> [args...]  (no sh -c, no eval)
            """
            body = self._read_json_body()
            if body is None:
                return  # _read_json_body already sent a 400

            cmd_str = body.get("cmd", "")
            if not isinstance(cmd_str, str) or not cmd_str.strip():
                self._send_json(400, {"error": "cmd field is required"})
                return

            tokens = cmd_str.split()
            if not tokens:
                self._send_json(400, {"error": "cmd is empty"})
                return

            subcommand = tokens[0]
            if subcommand not in ALLOWED_SUBCOMMANDS:
                self._send_json(
                    400,
                    {
                        "error": f"subcommand '{subcommand}' is not allowed",
                        "allowed": sorted(ALLOWED_SUBCOMMANDS),
                    },
                )
                return

            cmd_argv = [ww_bin] + tokens
            env = dict(os.environ)
            env["WW_BASE"] = state.ww_base

            try:
                result = subprocess.run(
                    cmd_argv,
                    capture_output=True,
                    text=True,
                    timeout=30,
                    env=env,
                )
                ok = result.returncode == 0
                output = result.stdout if ok else result.stderr
                self._send_json(
                    200,
                    {
                        "ok": ok,
                        "output": output,
                        "exit_code": result.returncode,
                    },
                )
            except subprocess.TimeoutExpired:
                self._send_json(
                    500,
                    {"ok": False, "output": "command timed out", "exit_code": -1},
                )
            except OSError as exc:
                self._send_json(
                    500,
                    {
                        "ok": False,
                        "output": f"failed to execute: {exc}",
                        "exit_code": -1,
                    },
                )

        # -- POST /profile ---------------------------------------------------

        def _handle_profile(self) -> None:
            """
            Switch the active profile server-side.

            Writes the new profile name to $WW_BASE/.state/active_profile and
            broadcasts an SSE 'profile' event to all connected clients.
            """
            body = self._read_json_body()
            if body is None:
                return

            name = body.get("profile", "")
            if not isinstance(name, str) or not name.strip():
                self._send_json(400, {"error": "profile field is required"})
                return

            name = name.strip()
            if not state.set_active_profile(name):
                self._send_json(400, {"ok": False, "error": "profile not found"})
                return

            state.broadcast("profile", json.dumps({"profile": name}))
            self._send_json(200, {"ok": True, "profile": name})

        # -- GET /data/tasks -------------------------------------------------

        def _handle_data_tasks(self) -> None:
            """Return pending and active tasks for the active profile as JSON."""
            paths = state.get_profile_paths()
            if not paths:
                self._send_json(200, {"ok": False, "error": "no active profile", "tasks": []})
                return
            env = {**os.environ, "TASKRC": paths["taskrc"], "TASKDATA": paths["taskdata"]}
            try:
                result = subprocess.run(
                    ["task", "rc.confirmation=no", "status:pending", "export"],
                    capture_output=True, text=True, timeout=10, env=env,
                )
                tasks = json.loads(result.stdout) if result.stdout.strip() else []
                # Also collect active tasks (may overlap with pending export)
                result2 = subprocess.run(
                    ["task", "rc.confirmation=no", "status:active", "export"],
                    capture_output=True, text=True, timeout=10, env=env,
                )
                active = json.loads(result2.stdout) if result2.stdout.strip() else []
                # Merge: active tasks first, pending de-duped by uuid
                all_tasks = active + [t for t in tasks if t.get("uuid") not in {a["uuid"] for a in active}]
                self._send_json(200, {"ok": True, "tasks": all_tasks})
            except Exception as exc:
                self._send_json(200, {"ok": False, "error": str(exc), "tasks": []})

        # -- GET /data/time --------------------------------------------------

        def _handle_data_time(self) -> None:
            """
            Parse TimeWarrior data files directly and return interval totals.
            Reads the current and previous month .data files to cover week boundaries.
            """
            paths = state.get_profile_paths()
            if not paths:
                self._send_json(200, {"ok": False, "error": "no active profile", "intervals": []})
                return
            twdb = paths["timewarriordb"]
            import glob as globmod
            import re as _re
            data_dir = os.path.join(twdb, "data")
            intervals = []
            now_utc = time.gmtime()
            current_month = time.strftime("%Y-%m", now_utc)
            prev_month = time.strftime("%Y-%m", time.gmtime(time.time() - 32 * 86400))
            active_interval = None
            for month in [prev_month, current_month]:
                data_file = os.path.join(data_dir, f"{month}.data")
                if not os.path.isfile(data_file):
                    continue
                for line in open(data_file):
                    line = line.strip()
                    if not line.startswith("inc "):
                        continue
                    # Closed interval: inc YYYYMMDDTHHMMSSZ - YYYYMMDDTHHMMSSZ # tags
                    # Open interval:   inc YYYYMMDDTHHMMSSZ # tags
                    m = _re.match(
                        r'inc (\d{8}T\d{6}Z)(?:\s+-\s+(\d{8}T\d{6}Z))?\s*(?:#\s*(.*))?', line
                    )
                    if not m:
                        continue
                    start_str, end_str, tags_str = m.group(1), m.group(2), m.group(3) or ""
                    start_ts = _parse_timew_ts(start_str)
                    if end_str:
                        end_ts = _parse_timew_ts(end_str)
                        duration = end_ts - start_ts
                        intervals.append({
                            "start": start_str,
                            "end": end_str,
                            "duration": int(duration),
                            "tags": tags_str.strip(),
                            "active": False,
                        })
                    else:
                        # No end time → currently active interval
                        active_interval = {
                            "start": start_str,
                            "end": None,
                            "duration": int(time.time() - start_ts),
                            "tags": tags_str.strip(),
                            "active": True,
                        }

            if active_interval:
                intervals.append(active_interval)

            # Compute today / week totals from local midnight boundaries
            today_start = time.mktime(time.strptime(time.strftime("%Y-%m-%d"), "%Y-%m-%d"))
            week_start = today_start - time.localtime().tm_wday * 86400
            today_total = sum(
                iv["duration"] for iv in intervals
                if _parse_timew_ts(iv["start"]) >= today_start
            )
            week_total = sum(
                iv["duration"] for iv in intervals
                if _parse_timew_ts(iv["start"]) >= week_start
            )
            self._send_json(200, {
                "ok": True,
                "intervals": intervals[-50:],  # cap at 50 most recent
                "today_total_seconds": today_total,
                "week_total_seconds": week_total,
                "active": active_interval is not None,
                "active_tags": active_interval["tags"] if active_interval else None,
                "active_since": active_interval["start"] if active_interval else None,
            })

        # -- GET /data/journal -----------------------------------------------

        def _handle_data_journal(self) -> None:
            """
            Read the profile's journal text file directly and return up to 20 entries.
            Does not invoke the jrnl CLI (too slow; requires config).
            Entry headers have the format: [YYYY-MM-DD HH:MM]
            """
            paths = state.get_profile_paths()
            if not paths:
                self._send_json(200, {"ok": False, "error": "no active profile", "entries": []})
                return
            journal_file = paths["journal_file"]
            try:
                import re as _re
                content = open(journal_file).read()
                # Split on [YYYY-MM-DD HH:MM] date headers
                parts = _re.split(r'\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\]', content)
                # parts layout: [pre, date1, body1, date2, body2, ...]
                entries = []
                for i in range(1, len(parts) - 1, 2):
                    date = parts[i]
                    body = parts[i + 1].strip()
                    if body:
                        entries.append({"date": date, "body": body})
                entries.reverse()  # most recent first
                self._send_json(200, {"ok": True, "entries": entries[:20]})
            except OSError:
                self._send_json(200, {"ok": True, "entries": []})

        # -- GET /data/ledger ------------------------------------------------

        def _handle_data_ledger(self) -> None:
            """
            Return account balances and recent transactions via hledger JSON output.
            Returns ok:false with an error message when hledger is not installed.
            """
            paths = state.get_profile_paths()
            if not paths:
                self._send_json(200, {"ok": False, "error": "no active profile"})
                return
            ledger_file = paths["ledger_file"]
            if not os.path.isfile(ledger_file):
                self._send_json(200, {"ok": True, "balances": [], "recent": []})
                return
            try:
                bal = subprocess.run(
                    ["hledger", "-f", ledger_file, "balance", "--output-format=json"],
                    capture_output=True, text=True, timeout=10,
                )
                reg = subprocess.run(
                    ["hledger", "-f", ledger_file, "register", "--output-format=json"],
                    capture_output=True, text=True, timeout=10,
                )
                balances = json.loads(bal.stdout) if bal.returncode == 0 and bal.stdout.strip() else []
                recent_raw = json.loads(reg.stdout) if reg.returncode == 0 and reg.stdout.strip() else []
                # Take only the last 10 register rows
                recent = recent_raw[-10:] if recent_raw else []
                self._send_json(200, {"ok": True, "balances": balances, "recent": recent})
            except FileNotFoundError:
                self._send_json(200, {"ok": False, "error": "hledger not installed",
                                      "balances": [], "recent": []})
            except Exception as exc:
                self._send_json(200, {"ok": False, "error": str(exc), "balances": [], "recent": []})

        # -- POST /action ----------------------------------------------------

        def _handle_action(self) -> None:
            """
            Execute a task or journal/ledger mutation and return the result.

            Supported actions:
              done, start, stop   — task lifecycle
              add                 — create a new task
              annotate            — add annotation to a task
              journal_add         — append an entry to the profile's journal file
              ledger_add          — append a transaction to the profile's ledger file
            """
            body = self._read_json_body()
            if body is None:
                return
            action = body.get("action", "")
            paths = state.get_profile_paths()
            if not paths:
                self._send_json(400, {"ok": False, "error": "no active profile"})
                return
            env = {**os.environ, "TASKRC": paths["taskrc"], "TASKDATA": paths["taskdata"]}

            def run_task(*args):
                return subprocess.run(
                    ["task", "rc.confirmation=no"] + list(args),
                    capture_output=True, text=True, timeout=15, env=env,
                )

            def fetch_tasks():
                r = subprocess.run(
                    ["task", "rc.confirmation=no", "status:pending", "export"],
                    capture_output=True, text=True, timeout=10, env=env,
                )
                r2 = subprocess.run(
                    ["task", "rc.confirmation=no", "status:active", "export"],
                    capture_output=True, text=True, timeout=10, env=env,
                )
                pending = json.loads(r.stdout) if r.stdout.strip() else []
                active = json.loads(r2.stdout) if r2.stdout.strip() else []
                return active + [t for t in pending if t.get("uuid") not in {a["uuid"] for a in active}]

            try:
                if action == "done":
                    tid = str(body.get("id", ""))
                    r = run_task(tid, "done")
                    tasks = fetch_tasks()
                    self._send_json(200, {"ok": r.returncode == 0, "output": r.stdout or r.stderr, "tasks": tasks})

                elif action == "start":
                    tid = str(body.get("id", ""))
                    r = run_task(tid, "start")
                    tasks = fetch_tasks()
                    self._send_json(200, {"ok": r.returncode == 0, "output": r.stdout or r.stderr, "tasks": tasks})

                elif action == "stop":
                    tid = str(body.get("id", ""))
                    r = run_task(tid, "stop")
                    tasks = fetch_tasks()
                    self._send_json(200, {"ok": r.returncode == 0, "output": r.stdout or r.stderr, "tasks": tasks})

                elif action == "add":
                    args_obj = body.get("args", {})
                    desc = args_obj.get("description", "")
                    if not desc:
                        self._send_json(400, {"ok": False, "error": "description required"})
                        return
                    cmd_parts = ["add", desc]
                    if args_obj.get("project"):
                        cmd_parts.append(f"project:{args_obj['project']}")
                    if args_obj.get("priority"):
                        cmd_parts.append(f"priority:{args_obj['priority']}")
                    if args_obj.get("due"):
                        cmd_parts.append(f"due:{args_obj['due']}")
                    for tag in args_obj.get("tags", []):
                        cmd_parts.append(f"+{tag}")
                    r = run_task(*cmd_parts)
                    tasks = fetch_tasks()
                    self._send_json(200, {"ok": r.returncode == 0, "output": r.stdout or r.stderr, "tasks": tasks})

                elif action == "annotate":
                    tid = str(body.get("id", ""))
                    note = body.get("args", {}).get("note", "")
                    r = run_task(tid, "annotate", note)
                    tasks = fetch_tasks()
                    self._send_json(200, {"ok": r.returncode == 0, "output": r.stdout or r.stderr, "tasks": tasks})

                elif action == "journal_add":
                    entry_text = body.get("args", {}).get("entry", "").strip()
                    if not entry_text:
                        self._send_json(400, {"ok": False, "error": "entry required"})
                        return
                    import time as time_mod
                    timestamp = time_mod.strftime("%Y-%m-%d %H:%M")
                    line = f"\n[{timestamp}] {entry_text}\n"
                    with open(paths["journal_file"], "a") as fh:
                        fh.write(line)
                    self._send_json(200, {"ok": True, "output": "entry added"})

                elif action == "ledger_add":
                    args_obj = body.get("args", {})
                    date = args_obj.get("date", time.strftime("%Y-%m-%d"))
                    desc = args_obj.get("description", "")
                    account = args_obj.get("account", "expenses:misc")
                    amount = args_obj.get("amount", "0")
                    if not desc:
                        self._send_json(400, {"ok": False, "error": "description required"})
                        return
                    entry = f"\n{date} {desc}\n    {account}  ${amount}\n    assets:checking\n"
                    with open(paths["ledger_file"], "a") as fh:
                        fh.write(entry)
                    self._send_json(200, {"ok": True, "output": "transaction added"})

                else:
                    self._send_json(400, {"ok": False, "error": f"unknown action: {action}"})

            except Exception as exc:
                self._send_json(500, {"ok": False, "error": str(exc)})

        # -- Helpers ---------------------------------------------------------

        def _read_json_body(self) -> dict | None:
            """
            Read and parse the request body as JSON.
            Returns None and sends a 400 if parsing fails.
            """
            length_header = self.headers.get("Content-Length")
            if length_header is None:
                self._send_json(400, {"error": "Content-Length header required"})
                return None
            try:
                length = int(length_header)
                raw = self.rfile.read(length)
                return json.loads(raw.decode("utf-8"))
            except (ValueError, json.JSONDecodeError) as exc:
                self._send_json(400, {"error": f"invalid JSON: {exc}"})
                return None

        def _send_json(self, status: int, payload: dict) -> None:
            body = json.dumps(payload).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    return Handler


# ---------------------------------------------------------------------------
# State file management
# ---------------------------------------------------------------------------

def _write_state_files(ww_base: str, pid: int, port: int) -> None:
    state_dir = os.path.join(ww_base, ".state")
    os.makedirs(state_dir, exist_ok=True)
    with open(os.path.join(state_dir, "browser.pid"), "w") as fh:
        fh.write(str(pid) + "\n")
    with open(os.path.join(state_dir, "browser.port"), "w") as fh:
        fh.write(str(port) + "\n")


def _remove_state_files(ww_base: str) -> None:
    for name in ("browser.pid", "browser.port"):
        path = os.path.join(ww_base, ".state", name)
        try:
            os.unlink(path)
        except OSError:
            pass


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        prog="server.py",
        description="Workwarrior browser HTTP server",
    )
    parser.add_argument("--port", type=int, default=7777, help="TCP port to listen on")
    parser.add_argument(
        "--no-open",
        action="store_true",
        help="Do not open browser tab (handled by browser.sh; flag accepted for compat)",
    )
    parser.add_argument(
        "--ww-base",
        default=os.environ.get("WW_BASE", os.path.expanduser("~/ww")),
        help="Workwarrior base directory (default: $WW_BASE or ~/ww)",
    )
    args = parser.parse_args()

    ww_base: str = args.ww_base
    port: int = args.port

    # Locate the ww binary relative to ww_base
    ww_bin = os.path.join(ww_base, "bin", "ww")

    # Initialise shared state
    state = ServerState(ww_base=ww_base)

    # Build the handler class (closes over state and ww_bin)
    HandlerClass = make_handler(state, ww_bin)

    # Attempt to bind the port before writing state files
    try:
        server = http.server.ThreadingHTTPServer(("", port), HandlerClass)
    except OSError as exc:
        if exc.errno == socket.errno.EADDRINUSE if hasattr(socket, "errno") else (
            "[Errno 48]" in str(exc) or "[Errno 98]" in str(exc) or "Address already in use" in str(exc)
        ):
            print(
                f"error: port {port} is already in use\n"
                f"Suggestion: ww browser --port {port + 1}",
                file=sys.stderr,
            )
        else:
            print(f"error: could not start server: {exc}", file=sys.stderr)
        sys.exit(1)

    # Write PID and port state files
    _write_state_files(ww_base, os.getpid(), port)

    # Graceful shutdown handler
    def _shutdown(signum, frame):  # noqa: ANN001
        state.request_shutdown()
        threading.Thread(target=server.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, _shutdown)
    signal.signal(signal.SIGINT, _shutdown)

    # Start ping/profile-watch thread
    ping_thread = threading.Thread(target=_ping_thread, args=(state,), daemon=True)
    ping_thread.start()

    try:
        server.serve_forever()
    finally:
        _remove_state_files(ww_base)


if __name__ == "__main__":
    main()
