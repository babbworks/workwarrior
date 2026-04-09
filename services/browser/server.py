#!/usr/bin/env python3
"""
services/browser/server.py — Workwarrior browser HTTP server

Python 3 stdlib only. ThreadingHTTPServer is required so that SSE connections
(which hold the socket open) do not block concurrent POST /cmd requests.

Endpoints:
  GET  /health   → 200 {"status":"ok","profile":"<active>","version":"1.0.0"}
  GET  /events   → text/event-stream SSE (connected + ping every 15s + profile events)
  POST /cmd      → run ww subcommand, return {"ok":bool,"output":"...","exit_code":N}
  POST /profile  → switch active profile, return {"ok":bool,"profile":"..."} or 400
  GET  /         → minimal placeholder HTML

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
            else:
                self._send_json(404, {"error": "not found"})

        def do_POST(self) -> None:  # noqa: N802
            if self.path == "/cmd":
                self._handle_cmd()
            elif self.path == "/profile":
                self._handle_profile()
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
