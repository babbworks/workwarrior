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
  POST /action        → task mutation (start/stop/done/add/annotate/journal_add/ledger_add/timew_start/timew_stop/timew_track)
  POST /resource/create → create a new named resource (journal/ledger/tasklist/timew)
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
import re
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
    "ctrl",
    "journal", "journals", "ledger", "ledgers",
    "tui", "mcp", "issues", "custom", "shortcut",
    "export", "find", "extensions", "deps",
    "version", "help", "browser",
    # task is a common alias people may use in tests
    "task",
    # weapons
    "gun", "next", "sword",
    # services
    "sync", "q", "questions",
    # management
    "remove",
])


def _to_bool(value: str, default: bool = False) -> bool:
    if value is None:
        return default
    v = _clean_yaml_scalar(value).lower()
    if v in {"true", "1", "yes", "on"}:
        return True
    if v in {"false", "0", "no", "off"}:
        return False
    return default


def _clean_yaml_scalar(value: str) -> str:
    v = str(value)
    if "#" in v:
        v = v.split("#", 1)[0]
    return v.strip().strip('"').strip("'")


def _read_ai_config(ww_base: str) -> dict:
    cfg = {
        "mode": "local-only",
        "access_points": {
            "cmd_ai": True,
            "sword_ai": False,
            "questions_ai": False,
            "saves_ai": False,
        },
        "preferred_provider": "ollama",
    }
    path = os.path.join(ww_base, "config", "ai.yaml")
    if not os.path.isfile(path):
        return cfg
    try:
        import re as _re
        current_section = ""
        with open(path, "r") as fh:
            for raw in fh:
                line = raw.strip()
                if not line or line.startswith("#"):
                    continue
                if _re.match(r"^[a-zA-Z0-9_]+:\s*$", line):
                    current_section = line[:-1]
                    continue
                if line.startswith("mode:"):
                    cfg["mode"] = _clean_yaml_scalar(line.split(":", 1)[1])
                elif line.startswith("preferred_provider:"):
                    cfg["preferred_provider"] = _clean_yaml_scalar(line.split(":", 1)[1])
                elif current_section == "access_points":
                    m = _re.match(r"^([a-zA-Z0-9_]+):\s*(.+)$", line)
                    if m:
                        cfg["access_points"][m.group(1)] = _to_bool(m.group(2), False)
    except Exception:
        pass

    # Per-profile override: profiles/<name>/ai.yaml
    profile = ""
    try:
        ap = os.path.join(ww_base, ".state", "active_profile")
        if os.path.isfile(ap):
            with open(ap) as f:
                profile = f.read().strip()
    except Exception:
        pass
    if profile:
        profile_ai = os.path.join(ww_base, "profiles", profile, "ai.yaml")
        if os.path.isfile(profile_ai):
            try:
                import re as _re2
                with open(profile_ai, "r") as fh:
                    for raw in fh:
                        line = raw.strip()
                        if line.startswith("mode:"):
                            cfg["mode"] = _clean_yaml_scalar(line.split(":", 1)[1])
                        elif line.startswith("preferred_provider:"):
                            cfg["preferred_provider"] = _clean_yaml_scalar(line.split(":", 1)[1])
            except Exception:
                pass

    return cfg


def _read_ctrl_config(ww_base: str) -> dict:
    cfg = {
        "command_line": {"show_ww": True, "show_ai": True},
        "ui": {"show_active_model": True},
    }
    path = os.path.join(ww_base, "config", "ctrl.yaml")
    if not os.path.isfile(path):
        return cfg
    try:
        section = ""
        with open(path, "r") as fh:
            for raw in fh:
                line = raw.strip()
                if not line or line.startswith("#"):
                    continue
                if line.endswith(":") and " " not in line:
                    section = line[:-1]
                    continue
                if ":" not in line:
                    continue
                key, value = [x.strip() for x in line.split(":", 1)]
                if section in cfg and key in cfg[section]:
                    cfg[section][key] = _to_bool(value, cfg[section][key])
    except Exception:
        pass
    return cfg


def _read_models_config(ww_base: str) -> dict:
    out = {"default_model": "", "providers": {}, "models": {}}
    path = os.path.join(ww_base, "config", "models.yaml")
    if not os.path.isfile(path):
        return out
    try:
        section = ""
        current_provider = ""
        current_model = ""
        with open(path, "r") as fh:
            for raw in fh:
                line = raw.rstrip("\n")
                s = line.strip()
                if not s or s.startswith("#"):
                    continue
                if s == "models:":
                    section = "models"
                    current_provider = ""
                    current_model = ""
                    continue
                if s == "providers:":
                    section = "providers"
                    current_provider = ""
                    current_model = ""
                    continue

                if section == "models":
                    if line.startswith("  ") and not line.startswith("    ") and s.endswith(":"):
                        key = s[:-1]
                        current_model = key
                        if key != "default":
                            out["models"].setdefault(current_model, {})
                        continue
                    if line.startswith("  default:"):
                        out["default_model"] = s.split(":", 1)[1].strip().strip('"').strip("'")
                        current_model = ""
                        continue
                    if current_model and line.startswith("    ") and ":" in s:
                        k, v = [x.strip() for x in s.split(":", 1)]
                        out["models"][current_model][k] = v.strip('"').strip("'")
                        continue

                if section == "providers":
                    if line.startswith("  ") and not line.startswith("    ") and s.endswith(":"):
                        current_provider = s[:-1]
                        out["providers"].setdefault(current_provider, {})
                        continue
                    if current_provider and line.startswith("    ") and ":" in s:
                        k, v = [x.strip() for x in s.split(":", 1)]
                        out["providers"][current_provider][k] = v.strip('"').strip("'")
                        continue
    except Exception:
        pass
    return out


def _resolve_ai_runtime(ww_base: str) -> dict:
    ai_cfg = _read_ai_config(ww_base)
    models_cfg = _read_models_config(ww_base)

    mode = ai_cfg.get("mode", "local-only")
    if mode == "off":
        return {
            "available": False,
            "reason": "AI is disabled (mode=off)",
            "mode": mode,
            "cmd_ai": bool(ai_cfg.get("access_points", {}).get("cmd_ai", True)),
            "provider": None,
            "model": None,
        }
    if not ai_cfg.get("access_points", {}).get("cmd_ai", True):
        return {
            "available": False,
            "reason": "CMD AI access is disabled in config/ai.yaml",
            "mode": mode,
            "cmd_ai": False,
            "provider": None,
            "model": None,
        }

    providers = models_cfg.get("providers", {})
    if not providers:
        return {
            "available": False,
            "reason": "No providers configured in config/models.yaml",
            "mode": mode,
            "cmd_ai": True,
            "provider": None,
            "model": None,
        }

    preferred = ai_cfg.get("preferred_provider", "").strip()
    provider_names = list(providers.keys())
    if preferred and preferred in providers:
        provider_names = [preferred] + [p for p in provider_names if p != preferred]

    default_model = models_cfg.get("default_model", "")
    default_model_cfg = models_cfg.get("models", {}).get(default_model, {}) if default_model else {}

    for pname in provider_names:
        p = providers.get(pname, {})
        ptype = p.get("type", "")
        if mode == "local-only" and ptype != "ollama":
            continue
        api_key = ""
        key_env = p.get("api_key_env", "")
        if ptype != "ollama":
            if not key_env:
                continue
            api_key = os.environ.get(key_env, "")
            if not api_key:
                continue
        model_id = ""
        if default_model_cfg and default_model_cfg.get("provider") == pname:
            model_id = default_model_cfg.get("id", "")
        if not model_id:
            for _, mcfg in models_cfg.get("models", {}).items():
                if mcfg.get("provider") == pname and mcfg.get("id"):
                    model_id = mcfg.get("id", "")
                    break
        if not model_id:
            model_id = "llama3.2" if ptype == "ollama" else "gpt-4o-mini"
        return {
            "available": True,
            "reason": "",
            "mode": mode,
            "cmd_ai": True,
            "provider": {
                "name": pname,
                "type": ptype,
                "base_url": p.get("base_url", ""),
                "api_key": api_key,
            },
            "model": model_id,
            "default_model": default_model,
            "preferred_provider": preferred,
            "all_models": models_cfg.get("models", {}),
        }

    reason = "No eligible provider available"
    if mode == "local-only":
        reason = "No local ollama provider available/running for local-only mode"
    return {
        "available": False,
        "reason": reason,
        "mode": mode,
        "cmd_ai": True,
        "provider": None,
        "model": None,
        "default_model": default_model,
        "preferred_provider": preferred,
    }


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
        # Active resource selections (per-session overrides; reset on profile switch)
        self._active_journal: str = "default"
        self._active_ledger: str = "default"
        self._active_tasklist: str = "default"
        self._active_timew: str = "default"

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

    def get_profile_resources(self) -> dict:
        """
        Return all named resources for the active profile:
          journals: {name: path, ...}
          ledgers:  {name: path, ...}
          tasklists: {"default": {taskrc, taskdata}} (future: multiple)
          timew:     {"default": path} (future: multiple)
        Returns empty dict when no profile is active.
        """
        import re as _re
        profile = self.get_active_profile()
        if not profile:
            return {}
        base = os.path.join(self.ww_base, "profiles", profile)

        # Journals
        journals: dict = {}
        jrnl_yaml = os.path.join(base, "jrnl.yaml")
        if os.path.isfile(jrnl_yaml):
            try:
                content = open(jrnl_yaml).read()
                in_journals = False
                for line in content.splitlines():
                    if line.strip() == "journals:":
                        in_journals = True
                        continue
                    if in_journals:
                        m = _re.match(r'^  (\w+):\s*(.+)', line)
                        if m:
                            journals[m.group(1)] = m.group(2).strip()
                        elif line and not line.startswith(' '):
                            in_journals = False
            except OSError:
                pass
        if not journals:
            journals["default"] = os.path.join(base, "journals", f"{profile}.txt")

        # Deduplicate: remove keys whose path duplicates 'default'
        default_j = journals.get("default", "")
        journals = {k: v for k, v in journals.items() if k == "default" or v != default_j}

        # Ledgers
        ledgers: dict = {}
        ledgers_yaml = os.path.join(base, "ledgers.yaml")
        if os.path.isfile(ledgers_yaml):
            try:
                content = open(ledgers_yaml).read()
                in_ledgers = False
                for line in content.splitlines():
                    if line.strip() == "ledgers:":
                        in_ledgers = True
                        continue
                    if in_ledgers:
                        m = _re.match(r'^  (\w+):\s*(.+)', line)
                        if m:
                            ledgers[m.group(1)] = m.group(2).strip()
                        elif line and not line.startswith(' '):
                            in_ledgers = False
            except OSError:
                pass
        if not ledgers:
            ledgers["default"] = os.path.join(base, "ledgers", f"{profile}.journal")

        # Deduplicate: remove keys whose path duplicates 'default'
        default_l = ledgers.get("default", "")
        ledgers = {k: v for k, v in ledgers.items() if k == "default" or v != default_l}

        # Task lists — currently one per profile; structure anticipates multiples
        tasklists: dict = {}
        tasklists_yaml = os.path.join(base, "tasklists.yaml")
        if os.path.isfile(tasklists_yaml):
            try:
                content = open(tasklists_yaml).read()
                in_section = False
                current_name = ""
                for line in content.splitlines():
                    if line.strip() == "tasklists:":
                        in_section = True
                        continue
                    if in_section:
                        # Top-level name line: "  name:"
                        m = _re.match(r'^  ([a-zA-Z0-9_-]+):\s*$', line)
                        if m:
                            current_name = m.group(1)
                            tasklists[current_name] = {}
                            continue
                        # Sub-key: "    taskrc: /path" or "    taskdata: /path"
                        m2 = _re.match(r'^    (taskrc|taskdata):\s*(.+)', line)
                        if m2 and current_name:
                            tasklists[current_name][m2.group(1)] = m2.group(2).strip()
                            continue
                        if line and not line.startswith(' '):
                            in_section = False
            except OSError:
                pass
        if not tasklists:
            tasklists["default"] = {
                "taskrc":   os.path.join(base, ".taskrc"),
                "taskdata": os.path.join(base, ".task"),
            }

        # TimeWarrior instances — currently one per profile; anticipates multiples
        timew: dict = {}
        timew_yaml = os.path.join(base, "timew.yaml")
        if os.path.isfile(timew_yaml):
            try:
                content = open(timew_yaml).read()
                in_section = False
                for line in content.splitlines():
                    if line.strip() == "timew:":
                        in_section = True
                        continue
                    if in_section:
                        m = _re.match(r'^  ([a-zA-Z0-9_-]+):\s*(.+)', line)
                        if m:
                            timew[m.group(1)] = m.group(2).strip()
                        elif line and not line.startswith(' '):
                            in_section = False
            except OSError:
                pass
        if not timew:
            timew["default"] = os.path.join(base, ".timewarrior")

        return {
            "journals":  journals,
            "ledgers":   ledgers,
            "tasklists": tasklists,
            "timew":     timew,
        }

    def get_profile_paths(self) -> dict:
        """
        Return resolved absolute paths for the currently selected resources.
        Respects active_journal / active_ledger / active_tasklist / active_timew
        session selections. Falls back to 'default' when selection is missing.
        Returns an empty dict when no profile is active.
        """
        resources = self.get_profile_resources()
        if not resources:
            return {}

        journals  = resources["journals"]
        ledgers   = resources["ledgers"]
        tasklists = resources["tasklists"]
        timew     = resources["timew"]

        journal_key  = self._active_journal  if self._active_journal  in journals  else "default"
        ledger_key   = self._active_ledger   if self._active_ledger   in ledgers   else "default"
        tasklist_key = self._active_tasklist if self._active_tasklist in tasklists else "default"
        timew_key    = self._active_timew    if self._active_timew    in timew     else "default"

        tl = tasklists.get(tasklist_key, tasklists.get("default", {}))
        return {
            "taskrc":        tl.get("taskrc", ""),
            "taskdata":      tl.get("taskdata", ""),
            "timewarriordb": timew.get(timew_key, timew.get("default", "")),
            "journal_file":  journals.get(journal_key, journals.get("default", "")),
            "ledger_file":   ledgers.get(ledger_key, ledgers.get("default", "")),
        }

    def set_active_profile(self, name: str) -> bool:
        """
        Write profile name to state file and reset resource selections.
        Returns True if the profile directory exists, False otherwise.
        """
        profile_dir = os.path.join(self.ww_base, "profiles", name)
        if not os.path.isdir(profile_dir):
            return False
        state_dir = os.path.join(self.ww_base, ".state")
        os.makedirs(state_dir, exist_ok=True)
        with open(self.active_profile_path, "w") as fh:
            fh.write(name + "\n")
        # Reset resource selections to defaults on profile switch
        with self.lock:
            self._active_journal  = "default"
            self._active_ledger   = "default"
            self._active_tasklist = "default"
            self._active_timew    = "default"
        return True

    def set_active_resource(self, kind: str, name: str) -> bool:
        """
        Switch the active named resource (journals/ledgers/tasklists/timew).
        Returns True if the resource name exists in the current profile.
        """
        resources = self.get_profile_resources()
        if not resources or kind not in resources:
            return False
        if name not in resources[kind]:
            return False
        attr_map = {
            "journals":  "_active_journal",
            "ledgers":   "_active_ledger",
            "tasklists": "_active_tasklist",
            "timew":     "_active_timew",
        }
        attr = attr_map.get(kind)
        if not attr:
            return False
        with self.lock:
            setattr(self, attr, name)
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
# Heuristic Engine — loads compiled rules, matches before AI
# ---------------------------------------------------------------------------

CONJUNCTIONS = re.compile(r'\b(?:and|then|also|plus)\b', re.IGNORECASE)


class HeuristicEngine:
    """Loads heuristic rules from YAML and matches natural language input."""

    def __init__(self, ww_base: str):
        self.rules = []
        self.threshold = 0.8
        self._ww_base = ww_base
        self._load_rules()

    def _load_rules(self):
        """Load and compile rules from config/cmd-heuristics.yaml."""
        yaml_path = os.path.join(self._ww_base, "config", "cmd-heuristics.yaml")
        if not os.path.isfile(yaml_path):
            return

        try:
            with open(yaml_path) as fh:
                content = fh.read()

            # Parse threshold
            import re as _re
            m = _re.search(r'^threshold:\s*([\d.]+)', content, _re.MULTILINE)
            if m:
                self.threshold = float(m.group(1))

            # Parse rules
            in_rules = False
            current = {}
            for line in content.splitlines():
                if line.strip() == "rules:":
                    in_rules = True
                    continue
                if not in_rules:
                    continue
                if line.strip().startswith("- pattern:"):
                    if current and "compiled_re" in current:
                        self.rules.append(current)
                    pattern_str = line.split(":", 1)[1].strip().strip('"')
                    current = {"pattern": pattern_str}
                    try:
                        current["compiled_re"] = re.compile(pattern_str, re.IGNORECASE)
                    except re.error:
                        current = {}
                elif line.strip().startswith("action:"):
                    current["action"] = line.split(":", 1)[1].strip().strip('"')
                elif line.strip().startswith("confidence:"):
                    try:
                        current["confidence"] = float(line.split(":", 1)[1].strip())
                    except ValueError:
                        current["confidence"] = 0.5
                elif line.strip().startswith("source:"):
                    current["source"] = line.split(":", 1)[1].strip()
                elif line.strip().startswith("count:"):
                    try:
                        current["count"] = int(line.split(":", 1)[1].strip())
                    except ValueError:
                        current["count"] = 0

            if current and "compiled_re" in current:
                self.rules.append(current)

        except Exception:
            pass  # graceful degradation — empty rules, AI handles everything

    def match(self, input_text: str):
        """Match input against all rules. Returns (action, confidence, rule_index) or None."""
        best = None
        best_confidence = 0
        best_index = -1

        for i, rule in enumerate(self.rules):
            compiled = rule.get("compiled_re")
            if not compiled:
                continue
            confidence = rule.get("confidence", 0)
            if confidence < self.threshold:
                continue

            m = compiled.search(input_text)
            if m and confidence > best_confidence:
                # Apply substitution
                action = rule.get("action", "")
                for gi, g in enumerate(m.groups(), 1):
                    if g:
                        action = action.replace(f"${gi}", g.strip())
                # Skip if action is empty after substitution
                if action.strip():
                    best = action
                    best_confidence = confidence
                    best_index = i

        if best:
            return best, best_confidence, best_index
        return None

    def increment_count(self, rule_index: int):
        """Increment usage count for a matched rule."""
        if 0 <= rule_index < len(self.rules):
            self.rules[rule_index]["count"] = self.rules[rule_index].get("count", 0) + 1

    def match_compound(self, input_text: str):
        """Try to match compound inputs by splitting on conjunctions
        and matching each segment independently.

        Returns a list of (action, confidence, rule_index) tuples if ALL
        segments match, or None if any segment fails to match (triggering
        AI fallback).
        """
        segments = CONJUNCTIONS.split(input_text)
        segments = [s.strip() for s in segments if s.strip()]

        # If only one segment (no conjunctions found), return None so the
        # caller falls through to the regular single match() path.
        if len(segments) <= 1:
            return None

        results = []
        last_action = None
        for segment in segments:
            # Support LAST context: if a previous segment produced a task add
            # command, replace the literal "LAST" placeholder in subsequent
            # segments so they can reference the created task.
            if last_action and "LAST" in segment:
                # LAST is resolved at execution time, not here — keep it as-is
                pass

            match_result = self.match(segment)
            if match_result is None:
                # Any unrecognizable segment → fall through to AI route
                return None

            action_str, confidence, rule_idx = match_result
            results.append((action_str, confidence, rule_idx))
            last_action = action_str

        return results


# ---------------------------------------------------------------------------
# Resource creation exceptions (used by _handle_resource_create helpers)
# ---------------------------------------------------------------------------

class _ResourceConflict(Exception):
    """Raised when a resource name already exists."""
    pass

class _ResourceBadRequest(Exception):
    """Raised for invalid resource creation requests."""
    pass


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

def make_handler(state: ServerState, ww_bin: str, heuristic_engine: HeuristicEngine = None):
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
            elif self.path == "/data/commands":
                self._handle_data_commands()
            elif self.path == "/data/all":
                self._handle_data_all()
            elif self.path == "/data/next":
                self._handle_data_next()
            elif self.path == "/data/schedule":
                self._handle_data_schedule()
            elif self.path == "/data/profile-resources":
                self._handle_data_profile_resources()
            elif self.path == "/data/accounts":
                self._handle_data_accounts()
            elif self.path == "/data/profiles":
                self._handle_data_profiles()
            elif self.path == "/data/cmd-log":
                self._handle_data_cmd_log()
            elif self.path == "/data/groups":
                self._handle_data_groups()
            elif self.path == "/data/network":
                self._handle_data_network()
            elif self.path == "/data/ctrl":
                self._handle_data_ctrl()
            elif self.path == "/data/timew-tags":
                self._handle_data_timew_tags()
            elif self.path == "/data/projects":
                self._handle_data_projects()
            elif self.path == "/data/udas":
                self._handle_data_udas()
            else:
                self._send_json(404, {"error": "not found"})

        def do_POST(self) -> None:  # noqa: N802
            if self.path == "/cmd":
                self._handle_cmd()
            elif self.path == "/profile":
                self._handle_profile()
            elif self.path == "/action":
                self._handle_action()
            elif self.path == "/resource":
                self._handle_resource()
            elif self.path == "/cmd/ai":
                self._handle_cmd_ai()
            elif self.path == "/resource/create":
                self._handle_resource_create()
            elif self.path == "/hledger":
                self._handle_hledger()
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

        # -- POST /cmd/ai ---------------------------------------------------

        def _handle_cmd_ai(self) -> None:
            """
            Accept a natural language instruction, call the configured LLM to
            translate it into one or more ww commands, execute them sequentially,
            and return the combined results.

            Body: {"prompt": "add a task for reviewing Q2 report due friday and start tracking time on it"}

            Reads provider config from config/models.yaml. Requires an API key
            env var to be set for the chosen provider.
            """
            import urllib.request
            import urllib.error

            body = self._read_json_body()
            if body is None:
                return
            prompt = body.get("prompt", "").strip()
            if not prompt:
                self._send_json(400, {"ok": False, "error": "prompt required"})
                return

            # Step 1: Try heuristic engine first (fastest, no LLM needed)
            if heuristic_engine:
                # Step 1a: Try compound match (multi-command with conjunctions)
                compound_result = heuristic_engine.match_compound(prompt)
                if compound_result is not None:
                    commands = []
                    all_results = []
                    paths = state.get_profile_paths()
                    task_env = {**os.environ, "TASKRC": paths.get("taskrc", ""), "TASKDATA": paths.get("taskdata", "")} if paths else {}
                    timew_env = {**os.environ, "TIMEWARRIORDB": paths.get("timewarriordb", "")} if paths else {}
                    min_confidence = 1.0

                    for action_str, confidence, rule_idx in compound_result:
                        heuristic_engine.increment_count(rule_idx)
                        if confidence < min_confidence:
                            min_confidence = confidence
                        segment_cmds = [line.strip() for line in action_str.splitlines() if line.strip()]
                        commands.extend(segment_cmds)

                        for cmd_str in segment_cmds:
                            tokens = cmd_str.split()
                            if not tokens:
                                continue
                            first = tokens[0].lower()
                            rest = tokens[1:]
                            try:
                                if first in ("task", "task_add"):
                                    if rest and rest[0] == "add":
                                        r = subprocess.run(["task", "rc.confirmation=no", "add"] + rest[1:],
                                            capture_output=True, text=True, timeout=15, env=task_env)
                                    elif rest and rest[0].isdigit() and len(rest) > 1:
                                        r = subprocess.run(["task", "rc.confirmation=no"] + rest,
                                            capture_output=True, text=True, timeout=15, env=task_env)
                                    else:
                                        r = subprocess.run(["task", "rc.confirmation=no", "add"] + rest,
                                            capture_output=True, text=True, timeout=15, env=task_env)
                                    all_results.append({"cmd": cmd_str, "ok": True, "output": (r.stdout or r.stderr).strip()})
                                elif first == "task_annotate":
                                    tid = rest[0] if rest else ""
                                    if tid == "LAST":
                                        r2 = subprocess.run(["task", "rc.confirmation=no", "+LATEST", "ids"],
                                            capture_output=True, text=True, timeout=5, env=task_env)
                                        tid = r2.stdout.strip().split()[-1] if r2.stdout.strip() else ""
                                    note = " ".join(rest[1:]) if len(rest) > 1 else ""
                                    if tid and note:
                                        r = subprocess.run(["task", "rc.confirmation=no", tid, "annotate", note],
                                            capture_output=True, text=True, timeout=15, env=task_env)
                                        all_results.append({"cmd": cmd_str, "ok": True, "output": (r.stdout or r.stderr).strip()})
                                    else:
                                        all_results.append({"cmd": cmd_str, "ok": False, "output": "task ID and note required"})
                                elif first in ("timew",):
                                    r = subprocess.run(["timew"] + rest, capture_output=True, text=True, timeout=10, env=timew_env)
                                    all_results.append({"cmd": cmd_str, "ok": True, "output": (r.stdout or r.stderr).strip()})
                                elif first == "journal_add":
                                    text = " ".join(rest)
                                    if text and paths:
                                        import time as time_mod
                                        ts = time_mod.strftime("%Y-%m-%d %H:%M")
                                        with open(paths["journal_file"], "a") as fh:
                                            fh.write(f"\n[{ts}] {text}\n")
                                        all_results.append({"cmd": cmd_str, "ok": True, "output": "journal entry added"})
                                    else:
                                        all_results.append({"cmd": cmd_str, "ok": False, "output": "no text or no profile"})
                                else:
                                    r = subprocess.run([ww_bin] + tokens, capture_output=True, text=True, timeout=30,
                                        env={**os.environ, "WW_BASE": state.ww_base})
                                    all_results.append({"cmd": cmd_str, "ok": r.returncode == 0, "output": (r.stdout or r.stderr).strip()})
                            except Exception as exc:
                                all_results.append({"cmd": cmd_str, "ok": False, "output": str(exc)})

                    self._send_json(200, {
                        "ok": True,
                        "route": "heuristic",
                        "provider": "none",
                        "model": "",
                        "mode": "heuristic",
                        "confidence": min_confidence,
                        "commands": commands,
                        "results": all_results,
                        "raw": " ; ".join(a for a, _, _ in compound_result),
                    })
                    return

                # Step 1b: Try single match
                match_result = heuristic_engine.match(prompt)
                if match_result:
                    action_str, confidence, rule_idx = match_result
                    heuristic_engine.increment_count(rule_idx)
                    commands = [line.strip() for line in action_str.splitlines() if line.strip()]
                    results = []
                    paths = state.get_profile_paths()
                    task_env = {**os.environ, "TASKRC": paths.get("taskrc", ""), "TASKDATA": paths.get("taskdata", "")} if paths else {}
                    timew_env = {**os.environ, "TIMEWARRIORDB": paths.get("timewarriordb", "")} if paths else {}

                    for cmd_str in commands:
                        tokens = cmd_str.split()
                        if not tokens:
                            continue
                        first = tokens[0].lower()
                        rest = tokens[1:]
                        try:
                            if first in ("task", "task_add"):
                                if rest and rest[0] == "add":
                                    r = subprocess.run(["task", "rc.confirmation=no", "add"] + rest[1:],
                                        capture_output=True, text=True, timeout=15, env=task_env)
                                elif rest and rest[0].isdigit() and len(rest) > 1:
                                    r = subprocess.run(["task", "rc.confirmation=no"] + rest,
                                        capture_output=True, text=True, timeout=15, env=task_env)
                                else:
                                    r = subprocess.run(["task", "rc.confirmation=no", "add"] + rest,
                                        capture_output=True, text=True, timeout=15, env=task_env)
                                results.append({"cmd": cmd_str, "ok": True, "output": (r.stdout or r.stderr).strip()})
                            elif first == "task_annotate":
                                tid = rest[0] if rest else ""
                                if tid == "LAST":
                                    r2 = subprocess.run(["task", "rc.confirmation=no", "+LATEST", "ids"],
                                        capture_output=True, text=True, timeout=5, env=task_env)
                                    tid = r2.stdout.strip().split()[-1] if r2.stdout.strip() else ""
                                note = " ".join(rest[1:]) if len(rest) > 1 else ""
                                if tid and note:
                                    r = subprocess.run(["task", "rc.confirmation=no", tid, "annotate", note],
                                        capture_output=True, text=True, timeout=15, env=task_env)
                                    results.append({"cmd": cmd_str, "ok": True, "output": (r.stdout or r.stderr).strip()})
                                else:
                                    results.append({"cmd": cmd_str, "ok": False, "output": "task ID and note required"})
                            elif first in ("timew",):
                                r = subprocess.run(["timew"] + rest, capture_output=True, text=True, timeout=10, env=timew_env)
                                results.append({"cmd": cmd_str, "ok": True, "output": (r.stdout or r.stderr).strip()})
                            elif first == "journal_add":
                                text = " ".join(rest)
                                if text and paths:
                                    import time as time_mod
                                    ts = time_mod.strftime("%Y-%m-%d %H:%M")
                                    with open(paths["journal_file"], "a") as fh:
                                        fh.write(f"\n[{ts}] {text}\n")
                                    results.append({"cmd": cmd_str, "ok": True, "output": "journal entry added"})
                                else:
                                    results.append({"cmd": cmd_str, "ok": False, "output": "no text or no profile"})
                            else:
                                r = subprocess.run([ww_bin] + tokens, capture_output=True, text=True, timeout=30,
                                    env={**os.environ, "WW_BASE": state.ww_base})
                                results.append({"cmd": cmd_str, "ok": r.returncode == 0, "output": (r.stdout or r.stderr).strip()})
                        except Exception as exc:
                            results.append({"cmd": cmd_str, "ok": False, "output": str(exc)})

                    self._send_json(200, {
                        "ok": True,
                        "route": "heuristic",
                        "provider": "none",
                        "model": "",
                        "mode": "heuristic",
                        "confidence": confidence,
                        "commands": commands,
                        "results": results,
                        "raw": action_str,
                    })
                    return

            # Step 2: Try AI route
            runtime = _resolve_ai_runtime(state.ww_base)
            if not runtime.get("available"):
                # No LLM available — use heuristic parsing directly
                commands = [prompt]  # treat the whole prompt as a single command
                provider_cfg = None
                model_id = ""
            else:
                provider_cfg = runtime.get("provider") or {}
                model_id = runtime.get("model") or ""

            # Build the system prompt — kept simple for small models
            profile = state.get_active_profile()
            system_prompt = (
                "Convert the user's request into workwarrior commands. "
                "Reply with ONLY the commands, one per line.\n\n"
                "Examples:\n"
                "User: add a task to review the budget due friday\n"
                "task add review the budget due:friday\n\n"
                "User: start tracking time on project meeting\n"
                "timew start project meeting\n\n"
                "User: stop tracking time\n"
                "timew stop\n\n"
                "User: add a journal entry about today's progress\n"
                "journal_add today's progress was good, shipped the new feature\n\n"
                "User: list all profiles\n"
                "profile list\n\n"
                "User: create a high priority task for the API review due next week\n"
                "task add API review priority:H due:1w\n\n"
                "User: create a task called fix the login page with annotation: check mobile layout\n"
                "task add fix the login page\n"
                "task_annotate LAST check mobile layout\n\n"
                "User: add a task go shopping due tomorrow and note: get milk and bread\n"
                "task add go shopping due:tomorrow\n"
                "task_annotate LAST get milk and bread\n\n"
                f"Active profile: {profile or 'none'}\n"
                "Reply with commands only. No explanations. One command per line."
            )

            try:
              if provider_cfg:
                # Try the configured model, with fallback to other available models
                models_to_try = [model_id] if model_id else []
                # Add other registered models as fallbacks
                for mname, mcfg in (runtime.get("all_models") or {}).items():
                    mid = mcfg.get("id", "")
                    if mid and mid not in models_to_try:
                        models_to_try.append(mid)
                if not models_to_try:
                    models_to_try = ["llama3.2:latest"]

                commands_text = ""
                used_model = ""
                for try_model in models_to_try:
                    try:
                        if provider_cfg["type"] == "ollama":
                            api_url = provider_cfg["base_url"].rstrip("/") + "/api/chat"
                            req_body = json.dumps({
                                "model": try_model,
                                "messages": [
                                    {"role": "system", "content": system_prompt},
                                    {"role": "user", "content": prompt},
                                ],
                                "stream": False,
                            }).encode("utf-8")
                        else:
                            api_url = provider_cfg["base_url"].rstrip("/") + "/chat/completions"
                            req_body = json.dumps({
                                "model": try_model,
                                "messages": [
                                    {"role": "system", "content": system_prompt},
                                    {"role": "user", "content": prompt},
                                ],
                                "temperature": 0.1,
                                "max_tokens": 500,
                            }).encode("utf-8")

                        req = urllib.request.Request(
                            api_url, data=req_body,
                            headers={"Content-Type": "application/json",
                                     **({"Authorization": f"Bearer {provider_cfg['api_key']}"} if provider_cfg.get("api_key") else {})},
                            method="POST",
                        )
                        with urllib.request.urlopen(req, timeout=30) as resp:
                            resp_data = json.loads(resp.read().decode("utf-8"))

                        if provider_cfg["type"] == "ollama":
                            commands_text = resp_data.get("message", {}).get("content", "")
                        else:
                            commands_text = resp_data.get("choices", [{}])[0].get("message", {}).get("content", "")

                        if commands_text.strip():
                            used_model = try_model
                            break
                    except Exception:
                        continue  # try next model

                if not commands_text.strip():
                    # All models failed — fall through to heuristic
                    commands = [prompt]
                    provider_cfg = None
                    model_id = ""
                else:
                    model_id = used_model

                # Parse into individual commands — strip markdown fences
                commands = [line.strip() for line in commands_text.strip().splitlines()
                           if line.strip() and not line.strip().startswith("#") and not line.strip().startswith("```")]
              else:
                # No LLM — commands already set to [prompt] above
                commands_text = prompt
                pass

                # Execute each command
                results = []
                paths = state.get_profile_paths()
                task_env = {**os.environ, "TASKRC": paths.get("taskrc", ""), "TASKDATA": paths.get("taskdata", "")} if paths else {}
                timew_env = {**os.environ, "TIMEWARRIORDB": paths.get("timewarriordb", "")} if paths else {}

                def _ai_exec_task(args):
                    r = subprocess.run(["task", "rc.confirmation=no"] + args,
                        capture_output=True, text=True, timeout=15, env=task_env)
                    return (r.stdout or r.stderr).strip()

                def _ai_exec_timew(args):
                    r = subprocess.run(["timew"] + args,
                        capture_output=True, text=True, timeout=10, env=timew_env)
                    return (r.stdout or r.stderr).strip()

                for cmd_str in commands:
                    tokens = cmd_str.split()
                    # Strip leading ww/ACTION
                    if tokens and tokens[0].lower() in ("ww", "action"):
                        tokens = tokens[1:]
                    if not tokens:
                        continue
                    first = tokens[0].lower()
                    rest = tokens[1:]

                    try:
                        if first in ("task", "task_add"):
                            if not rest or (len(rest) == 0):
                                results.append({"cmd": cmd_str, "ok": False, "output": "task needs arguments"})
                            elif rest[0] == "add":
                                out = _ai_exec_task(["add"] + rest[1:])
                                results.append({"cmd": cmd_str, "ok": True, "output": out})
                            elif rest[0].isdigit() and len(rest) > 1:
                                out = _ai_exec_task(rest)
                                results.append({"cmd": cmd_str, "ok": True, "output": out})
                            else:
                                out = _ai_exec_task(["add"] + rest)
                                results.append({"cmd": cmd_str, "ok": True, "output": out})
                        elif first in ("task_start", "task_stop", "task_done"):
                            action_word = first.split("_")[1]
                            tid = rest[0] if rest else ""
                            if tid:
                                out = _ai_exec_task([tid, action_word])
                                results.append({"cmd": cmd_str, "ok": True, "output": out})
                            else:
                                results.append({"cmd": cmd_str, "ok": False, "output": f"task ID required for {action_word}"})
                        elif first == "task_annotate":
                            tid = rest[0] if rest else ""
                            note = " ".join(rest[1:]) if len(rest) > 1 else ""
                            # LAST = annotate the most recently created task
                            if tid == "LAST":
                                r = subprocess.run(["task", "rc.confirmation=no", "+LATEST", "ids"],
                                    capture_output=True, text=True, timeout=5, env=task_env)
                                tid = r.stdout.strip().split()[-1] if r.stdout.strip() else ""
                            if tid and note:
                                out = _ai_exec_task([tid, "annotate", note])
                                results.append({"cmd": cmd_str, "ok": True, "output": out})
                            else:
                                results.append({"cmd": cmd_str, "ok": False, "output": "task ID and note required"})
                        elif first in ("task_modify",):
                            tid = rest[0] if rest else ""
                            mods = rest[1:] if len(rest) > 1 else []
                            if tid and mods:
                                out = _ai_exec_task([tid, "modify"] + mods)
                                results.append({"cmd": cmd_str, "ok": True, "output": out})
                            else:
                                results.append({"cmd": cmd_str, "ok": False, "output": "task ID and modifications required"})
                        elif first in ("timew", "timew_start", "timew_stop", "timew_track"):
                            if first == "timew_start" or (rest and rest[0] == "start"):
                                args = rest[1:] if rest and rest[0] == "start" else rest
                                out = _ai_exec_timew(["start"] + args)
                                results.append({"cmd": cmd_str, "ok": True, "output": out})
                            elif first == "timew_stop" or (rest and rest[0] == "stop"):
                                out = _ai_exec_timew(["stop"])
                                results.append({"cmd": cmd_str, "ok": True, "output": out})
                            else:
                                out = _ai_exec_timew(rest if rest else [])
                                results.append({"cmd": cmd_str, "ok": True, "output": out})
                        elif first in ("journal_add", "journal"):
                            text = " ".join(rest[1:] if rest and rest[0] == "add" else rest)
                            if text and paths:
                                import time as time_mod
                                ts = time_mod.strftime("%Y-%m-%d %H:%M")
                                with open(paths["journal_file"], "a") as fh:
                                    fh.write(f"\n[{ts}] {text}\n")
                                results.append({"cmd": cmd_str, "ok": True, "output": "journal entry added"})
                            else:
                                results.append({"cmd": cmd_str, "ok": False, "output": "no text or no profile"})
                        elif first in ALLOWED_SUBCOMMANDS:
                            r = subprocess.run([ww_bin] + tokens, capture_output=True, text=True, timeout=30,
                                env={**os.environ, "WW_BASE": state.ww_base})
                            results.append({"cmd": cmd_str, "ok": r.returncode == 0, "output": (r.stdout or r.stderr).strip()})
                        else:
                            out = _ai_exec_task(["add"] + tokens)
                            results.append({"cmd": cmd_str, "ok": True, "output": f"(→ task add) {out}"})
                    except Exception as exc:
                        results.append({"cmd": cmd_str, "ok": False, "output": str(exc)})

                self._send_json(200, {
                    "ok": True,
                    "route": "ai" if provider_cfg else "heuristic",
                    "provider": provider_cfg["name"] if provider_cfg else "none",
                    "model": model_id or "",
                    "mode": runtime.get("mode", "local-only") if runtime.get("available") else "heuristic",
                    "commands": commands,
                    "results": results,
                    "raw": commands_text if provider_cfg else prompt,
                })

            except urllib.error.URLError as exc:
                self._send_json(200, {"ok": False, "error": f"LLM request failed: {exc}", "fallback": True})
            except Exception as exc:
                self._send_json(200, {"ok": False, "error": f"AI error: {exc}", "fallback": True})

        # -- POST /hledger ---------------------------------------------------

        def _handle_hledger(self) -> None:
            """
            Run any hledger command against the active profile's ledger.
            Body: {"cmd": "balancesheet", "args": ["--monthly"], "period": ""}
            Returns the text output.
            """
            body = self._read_json_body()
            if body is None:
                return
            hcmd = body.get("cmd", "").strip()
            hargs = body.get("args", [])
            if not hcmd:
                self._send_json(400, {"ok": False, "error": "cmd required"})
                return

            # Whitelist of safe hledger commands
            safe_cmds = {
                "balance", "bal", "balancesheet", "bs", "balancesheetequity", "bse",
                "incomestatement", "is", "cashflow", "cf",
                "register", "reg", "aregister", "areg",
                "accounts", "stats", "activity", "print",
                "codes", "descriptions", "payees", "notes", "tags",
                "prices", "commodities", "roi", "check", "files",
            }
            if hcmd not in safe_cmds:
                self._send_json(400, {"ok": False, "error": f"command '{hcmd}' not allowed"})
                return

            paths = state.get_profile_paths()
            if not paths:
                self._send_json(400, {"ok": False, "error": "no active profile"})
                return
            ledger_file = paths["ledger_file"]
            if not os.path.isfile(ledger_file):
                self._send_json(200, {"ok": False, "error": "no ledger file"})
                return

            cmd = ["hledger", "-f", ledger_file, hcmd] + [str(a) for a in hargs]
            try:
                # Ensure common binary paths are in PATH for hledger
                env = dict(os.environ)
                for p in ["/usr/local/bin", "/opt/homebrew/bin", os.path.expanduser("~/.local/bin")]:
                    if p not in env.get("PATH", ""):
                        env["PATH"] = p + ":" + env.get("PATH", "")
                r = subprocess.run(cmd, capture_output=True, text=True, timeout=15, env=env)
                self._send_json(200, {
                    "ok": r.returncode == 0,
                    "output": (r.stdout if r.returncode == 0 else r.stderr).strip(),
                    "cmd": " ".join(cmd),
                })
            except FileNotFoundError:
                self._send_json(200, {"ok": False, "error": "hledger not installed"})
            except Exception as exc:
                self._send_json(200, {"ok": False, "error": str(exc)})

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
            Return account balances and recent transactions via hledger text output.

            Uses --flat --no-total for balance (one account per line) and TSV for
            register (date, description, account, amount, balance columns).
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
                import re as _re
                # Balance: flat list with no total summary line
                bal = subprocess.run(
                    ["hledger", "-f", ledger_file, "balance", "--flat", "--no-total"],
                    capture_output=True, text=True, timeout=10,
                )
                # Register: TSV output (date, description, account, amount, balance)
                reg = subprocess.run(
                    ["hledger", "-f", ledger_file, "register", "-O", "tsv"],
                    capture_output=True, text=True, timeout=10,
                )
                balances = []
                if bal.returncode == 0:
                    for line in bal.stdout.splitlines():
                        line = line.rstrip()
                        if not line.strip():
                            continue
                        # format: "          $1,234.56  account:name"
                        m = _re.match(r'\s+([-$£€\d,. ]+\S)\s{2,}(\S+.*)', line)
                        if m:
                            balances.append({
                                "amount": m.group(1).strip(),
                                "account": m.group(2).strip(),
                            })
                recent = []
                if reg.returncode == 0:
                    lines = reg.stdout.splitlines()
                    # Skip header row if present (starts with "txnidx" or "date")
                    data_lines = [
                        l for l in lines
                        if l and not l.startswith("txnidx") and not l.startswith("date")
                    ]
                    for line in data_lines[-15:]:
                        parts = line.split('\t')
                        if len(parts) >= 6:
                            recent.append({
                                "date":        parts[1],
                                "description": parts[3],
                                "account":     parts[4],
                                "amount":      parts[5],
                                "balance":     parts[6] if len(parts) > 6 else "",
                            })
                self._send_json(200, {"ok": True, "balances": balances, "recent": recent})
            except FileNotFoundError:
                self._send_json(200, {"ok": False, "error": "hledger not installed",
                                      "balances": [], "recent": []})
            except Exception as exc:
                self._send_json(200, {"ok": False, "error": str(exc), "balances": [], "recent": []})

        # -- GET /data/accounts ---------------------------------------------

        def _handle_data_accounts(self) -> None:
            """
            Return known account names from the active ledger file.
            Uses `hledger accounts` which returns both declared and used accounts.
            """
            paths = state.get_profile_paths()
            if not paths:
                self._send_json(200, {"ok": True, "accounts": []})
                return
            ledger_file = paths["ledger_file"]
            if not os.path.isfile(ledger_file):
                self._send_json(200, {"ok": True, "accounts": []})
                return
            try:
                r = subprocess.run(
                    ["hledger", "-f", ledger_file, "accounts"],
                    capture_output=True, text=True, timeout=10,
                )
                accounts = [a.strip() for a in r.stdout.splitlines() if a.strip()]
                self._send_json(200, {"ok": True, "accounts": accounts})
            except FileNotFoundError:
                self._send_json(200, {"ok": True, "accounts": []})
            except Exception as exc:
                self._send_json(200, {"ok": False, "error": str(exc), "accounts": []})

        # -- GET /data/profiles ---------------------------------------------

        def _handle_data_profiles(self) -> None:
            """Return list of profile names by scanning the profiles directory."""
            profiles_dir = os.path.join(state.ww_base, "profiles")
            try:
                names = sorted([
                    d for d in os.listdir(profiles_dir)
                    if os.path.isdir(os.path.join(profiles_dir, d)) and not d.startswith('.')
                ])
                self._send_json(200, {
                    "ok": True,
                    "profiles": names,
                    "active": state.get_active_profile(),
                })
            except OSError:
                self._send_json(200, {"ok": True, "profiles": [], "active": ""})

        # -- GET /data/cmd-log ----------------------------------------------

        def _handle_data_cmd_log(self) -> None:
            """Return the CMD service log entries."""
            log_path = os.path.join(state.ww_base, "services", "cmd", "cmd.log")
            if not os.path.isfile(log_path):
                self._send_json(200, {"ok": True, "entries": []})
                return
            try:
                entries = []
                with open(log_path, "r") as fh:
                    for line in fh:
                        line = line.strip()
                        if not line:
                            continue
                        try:
                            entries.append(json.loads(line))
                        except json.JSONDecodeError:
                            pass
                entries.reverse()  # newest first
                self._send_json(200, {"ok": True, "entries": entries[:100]})
            except Exception as exc:
                self._send_json(200, {"ok": False, "error": str(exc), "entries": []})

        # -- GET /data/groups -----------------------------------------------

        def _handle_data_groups(self) -> None:
            """Return groups from config/groups.yaml."""
            groups_yaml = os.path.join(state.ww_base, "config", "groups.yaml")
            if not os.path.isfile(groups_yaml):
                self._send_json(200, {"ok": True, "groups": {}})
                return
            try:
                import re as _re
                content = open(groups_yaml).read()
                groups = {}
                current = ""
                in_profiles = False
                for line in content.splitlines():
                    m = _re.match(r'^  (\w[\w-]*):', line)
                    if m:
                        current = m.group(1)
                        groups[current] = []
                        in_profiles = False
                        continue
                    if current and line.strip() == "profiles:":
                        in_profiles = True
                        continue
                    if in_profiles:
                        pm = _re.match(r'^\s+- (.+)', line)
                        if pm:
                            groups[current].append(pm.group(1).strip())
                        elif line and not line.startswith(' '):
                            in_profiles = False
                self._send_json(200, {"ok": True, "groups": groups})
            except Exception as exc:
                self._send_json(200, {"ok": False, "error": str(exc), "groups": {}})

        # -- GET /data/network ----------------------------------------------

        def _handle_data_network(self) -> None:
            """Return network connectivity stats including IP and latency."""
            import urllib.request
            import urllib.error

            checks = []
            # Internet connectivity + external IP
            try:
                start = time.time()
                req = urllib.request.Request("https://httpbin.org/ip", method="GET")
                with urllib.request.urlopen(req, timeout=5) as resp:
                    latency = int((time.time() - start) * 1000)
                    body = json.loads(resp.read().decode("utf-8"))
                    checks.append({"name": "internet", "ok": True, "status": f"{latency}ms", "ip": body.get("origin", "")})
            except Exception as exc:
                checks.append({"name": "internet", "ok": False, "status": str(exc), "ip": ""})

            # GitHub API
            try:
                start = time.time()
                req = urllib.request.Request("https://api.github.com", method="GET")
                with urllib.request.urlopen(req, timeout=5) as resp:
                    latency = int((time.time() - start) * 1000)
                    checks.append({"name": "github", "ok": True, "status": f"{latency}ms"})
            except Exception as exc:
                checks.append({"name": "github", "ok": False, "status": str(exc)})

            # Ollama
            try:
                start = time.time()
                req = urllib.request.Request("http://localhost:11434/api/tags", method="GET")
                with urllib.request.urlopen(req, timeout=3) as resp:
                    latency = int((time.time() - start) * 1000)
                    data = json.loads(resp.read().decode("utf-8"))
                    models = [m["name"] for m in data.get("models", [])]
                    checks.append({"name": "ollama", "ok": True, "status": f"{latency}ms · {len(models)} model(s)", "models": models})
            except Exception:
                checks.append({"name": "ollama", "ok": False, "status": "not running"})

            # Local hostname and interfaces
            try:
                hostname = socket.gethostname()
                local_ip = socket.gethostbyname(hostname)
                checks.append({"name": "local", "ok": True, "status": f"{hostname} · {local_ip}"})
            except Exception:
                checks.append({"name": "local", "ok": True, "status": socket.gethostname()})

            # DNS resolution speed
            try:
                start = time.time()
                socket.getaddrinfo("github.com", 443)
                latency = int((time.time() - start) * 1000)
                checks.append({"name": "dns", "ok": True, "status": f"{latency}ms (github.com)"})
            except Exception as exc:
                checks.append({"name": "dns", "ok": False, "status": str(exc)})

            self._send_json(200, {"ok": True, "checks": checks})

        # -- GET /data/ctrl -------------------------------------------------

        def _handle_data_ctrl(self) -> None:
            """Return merged CTRL + AI status for browser UI controls."""
            ai_cfg = _read_ai_config(state.ww_base)
            ctrl_cfg = _read_ctrl_config(state.ww_base)
            runtime = _resolve_ai_runtime(state.ww_base)
            self._send_json(200, {
                "ok": True,
                "ai": {
                    "mode": ai_cfg.get("mode", "local-only"),
                    "cmd_ai": bool(ai_cfg.get("access_points", {}).get("cmd_ai", True)),
                    "preferred_provider": ai_cfg.get("preferred_provider", "ollama"),
                    "available": bool(runtime.get("available", False)),
                    "provider": (runtime.get("provider") or {}).get("name", ""),
                    "model": runtime.get("model", "") or "",
                    "reason": runtime.get("reason", ""),
                },
                "command_line": ctrl_cfg.get("command_line", {}),
                "ui": ctrl_cfg.get("ui", {}),
            })

        # -- GET /data/timew-tags -------------------------------------------

        def _handle_data_timew_tags(self) -> None:
            """Return known timewarrior tags for autocomplete."""
            paths = state.get_profile_paths()
            if not paths:
                self._send_json(200, {"ok": True, "tags": []})
                return
            timew_env = {**os.environ, "TIMEWARRIORDB": paths["timewarriordb"]}
            try:
                r = subprocess.run(["timew", "tags"], capture_output=True, text=True, timeout=10, env=timew_env)
                tags = []
                for line in (r.stdout or "").splitlines():
                    line = line.strip()
                    if line and not line.startswith("Tag") and not line.startswith("---"):
                        # Format: "tag_name   - description" or just "tag_name"
                        tag = line.split(" - ")[0].strip().split("  ")[0].strip()
                        if tag:
                            tags.append(tag)
                self._send_json(200, {"ok": True, "tags": tags})
            except Exception:
                self._send_json(200, {"ok": True, "tags": []})

        # -- GET /data/udas --------------------------------------------------

        def _handle_data_udas(self) -> None:
            """Return UDA definitions from the active profile's .taskrc."""
            paths = state.get_profile_paths()
            if not paths:
                self._send_json(200, {"ok": True, "udas": []})
                return
            taskrc = paths["taskrc"]
            if not os.path.isfile(taskrc):
                self._send_json(200, {"ok": True, "udas": []})
                return
            import re as _re
            udas = []
            types = {}
            labels = {}
            try:
                with open(taskrc, "r") as fh:
                    for line in fh:
                        m = _re.match(r'^uda\.([^.]+)\.type=(.+)', line.strip())
                        if m:
                            types[m.group(1)] = m.group(2)
                        m2 = _re.match(r'^uda\.([^.]+)\.label=(.+)', line.strip())
                        if m2:
                            labels[m2.group(1)] = m2.group(2)
                for name, utype in sorted(types.items()):
                    # Skip service UDAs
                    if any(name.startswith(p) for p in ["github", "gitlab", "jira", "trello", "bw_", "sync_"]):
                        continue
                    udas.append({"name": name, "type": utype, "label": labels.get(name, name)})
            except Exception:
                pass
            self._send_json(200, {"ok": True, "udas": udas})

        # -- GET /data/projects ---------------------------------------------

        def _handle_data_projects(self) -> None:
            """Return projects from config/projects.yaml."""
            projects_yaml = os.path.join(state.ww_base, "config", "projects.yaml")
            if not os.path.isfile(projects_yaml):
                self._send_json(200, {"ok": True, "projects": {}})
                return
            try:
                import re as _re
                content = open(projects_yaml).read()
                projects = {}
                current = ""
                for line in content.splitlines():
                    m = _re.match(r'^  (\w[\w-]*):', line)
                    if m and not line.strip().endswith(':'):
                        # key: value on same line
                        continue
                    if m:
                        current = m.group(1)
                        projects[current] = {"description": "", "tasks": [], "journals": [], "ledgers": [], "tags": []}
                        continue
                    if current:
                        km = _re.match(r'^\s+(description|tasks|journals|ledgers|tags):\s*(.*)', line)
                        if km:
                            key, val = km.groups()
                            if val.strip():
                                projects[current][key] = val.strip()
                        lm = _re.match(r'^\s+- (.+)', line)
                        if lm:
                            # Add to the last key that was a list
                            pass
                self._send_json(200, {"ok": True, "projects": projects})
            except Exception as exc:
                self._send_json(200, {"ok": False, "error": str(exc), "projects": {}})

        # -- GET /data/all (for export) -------------------------------------

        def _handle_data_all(self) -> None:
            """Aggregate all profile data into one JSON response for static export."""
            import threading as _threading
            results = {}
            errors = {}

            def fetch(name, fn):
                try:
                    results[name] = fn()
                except Exception as exc:
                    errors[name] = str(exc)

            # Reuse existing data methods by calling their logic directly
            paths = state.get_profile_paths()
            profile = state.get_active_profile()

            if not paths:
                self._send_json(200, {"ok": False, "error": "no active profile"})
                return

            env_t = {**os.environ, "TASKRC": paths["taskrc"], "TASKDATA": paths["taskdata"]}

            # Tasks
            try:
                r1 = subprocess.run(["task", "rc.confirmation=no", "status:pending", "export"],
                    capture_output=True, text=True, timeout=10, env=env_t)
                r2 = subprocess.run(["task", "rc.confirmation=no", "status:active", "export"],
                    capture_output=True, text=True, timeout=10, env=env_t)
                pending = json.loads(r1.stdout) if r1.stdout.strip() else []
                active = json.loads(r2.stdout) if r2.stdout.strip() else []
                tasks = active + [t for t in pending if t.get("uuid") not in {a["uuid"] for a in active}]
            except Exception:
                tasks = []

            # Journal
            try:
                import re as _re
                content_j = open(paths["journal_file"]).read()
                parts = _re.split(r'\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\]', content_j)
                journal_entries = []
                for i in range(1, len(parts) - 1, 2):
                    body = parts[i + 1].strip()
                    if body:
                        journal_entries.append({"date": parts[i], "body": body})
                journal_entries.reverse()
                journal_entries = journal_entries[:20]
            except Exception:
                journal_entries = []

            # Ledger balances
            try:
                bal = subprocess.run(
                    ["hledger", "-f", paths["ledger_file"], "balance", "--flat", "--no-total"],
                    capture_output=True, text=True, timeout=10)
                import re as _re2
                balances = []
                if bal.returncode == 0:
                    for line in bal.stdout.splitlines():
                        m = _re2.match(r'\s+([-$£€\d,. ]+\S)\s{2,}(\S+.*)', line.rstrip())
                        if m:
                            balances.append({"amount": m.group(1).strip(), "account": m.group(2).strip()})
            except Exception:
                balances = []

            self._send_json(200, {
                "ok": True,
                "profile": profile,
                "exported_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "tasks": tasks,
                "journal": journal_entries,
                "balances": balances,
            })

        # -- GET /data/next -------------------------------------------------

        def _handle_data_next(self) -> None:
            """Return the highest-urgency pending task as the recommended next task."""
            paths = state.get_profile_paths()
            if not paths:
                self._send_json(200, {"ok": False, "error": "no active profile", "task": None})
                return
            env = {**os.environ, "TASKRC": paths["taskrc"], "TASKDATA": paths["taskdata"]}
            try:
                # Use status:pending sorted by urgency descending, limit 1
                r = subprocess.run(
                    ["task", "rc.confirmation=no", "status:pending", "export"],
                    capture_output=True, text=True, timeout=10, env=env,
                )
                tasks = json.loads(r.stdout) if r.stdout.strip() else []
                if tasks:
                    tasks.sort(key=lambda t: t.get("urgency", 0), reverse=True)
                self._send_json(200, {"ok": True, "task": tasks[0] if tasks else None})
            except Exception as exc:
                self._send_json(200, {"ok": False, "error": str(exc), "task": None})

        # -- GET /data/schedule ---------------------------------------------

        def _handle_data_schedule(self) -> None:
            """Return schedule service status."""
            ww_bin_path = os.path.join(state.ww_base, "bin", "ww")
            env = {**os.environ, "WW_BASE": state.ww_base}
            try:
                r = subprocess.run(
                    [ww_bin_path, "schedule", "status"],
                    capture_output=True, text=True, timeout=10, env=env,
                )
                output = (r.stdout or r.stderr).strip()
                enabled = r.returncode == 0 and "enabled" in output.lower()
                self._send_json(200, {"ok": True, "enabled": enabled, "output": output})
            except Exception as exc:
                self._send_json(200, {"ok": False, "error": str(exc), "enabled": False, "output": ""})

        # -- GET /data/profile-resources ------------------------------------

        def _handle_data_profile_resources(self) -> None:
            """
            Return all named resources for the active profile plus current selections.
            Used by the UI to populate resource selector dropdowns.
            """
            resources = state.get_profile_resources()
            if not resources:
                self._send_json(200, {"ok": False, "error": "no active profile"})
                return
            self._send_json(200, {
                "ok": True,
                "resources": resources,
                "active": {
                    "journal":  state._active_journal,
                    "ledger":   state._active_ledger,
                    "tasklist": state._active_tasklist,
                    "timew":    state._active_timew,
                },
            })

        # -- POST /resource --------------------------------------------------

        def _handle_resource(self) -> None:
            """
            Switch the active named resource for the current profile session.
            Body: {"kind": "journals"|"ledgers"|"tasklists"|"timew", "name": "<key>"}
            """
            body = self._read_json_body()
            if body is None:
                return
            kind = body.get("kind", "")
            name = body.get("name", "")
            if not kind or not name:
                self._send_json(400, {"error": "kind and name required"})
                return
            if not state.set_active_resource(kind, name):
                self._send_json(400, {"ok": False, "error": f"resource '{name}' not found in {kind}"})
                return
            self._send_json(200, {"ok": True, "kind": kind, "name": name})

        # -- POST /resource/create -------------------------------------------

        def _handle_resource_create(self) -> None:
            """
            Create a new named resource for the active profile.
            Body: {"kind": "journals"|"ledgers"|"tasklists"|"timew", "name": "<key>"}

            - Validates the name (alphanumeric, hyphens, underscores only).
            - Creates the backing files/dirs on disk.
            - Registers the resource in the profile's config YAML.
            - Returns the updated resource map so the UI can refresh.
            """
            import re as _re

            body = self._read_json_body()
            if body is None:
                return
            kind = body.get("kind", "")
            name = body.get("name", "").strip()

            valid_kinds = ("journals", "ledgers", "tasklists", "timew")
            if kind not in valid_kinds:
                self._send_json(400, {"ok": False, "error": f"kind must be one of {valid_kinds}"})
                return
            if not name:
                self._send_json(400, {"ok": False, "error": "name required"})
                return
            if not _re.fullmatch(r'[a-zA-Z0-9_-]+', name):
                self._send_json(400, {
                    "ok": False,
                    "error": "name may only contain letters, numbers, hyphens, and underscores",
                })
                return

            profile = state.get_active_profile()
            if not profile:
                self._send_json(400, {"ok": False, "error": "no active profile"})
                return
            profile_base = os.path.join(state.ww_base, "profiles", profile)

            try:
                if kind == "journals":
                    self._create_journal_resource(profile_base, name, _re)
                elif kind == "ledgers":
                    self._create_ledger_resource(profile_base, name, _re)
                elif kind == "tasklists":
                    self._create_tasklist_resource(profile_base, name, _re)
                elif kind == "timew":
                    self._create_timew_resource(profile_base, name, _re)
            except _ResourceConflict as exc:
                self._send_json(409, {"ok": False, "error": str(exc)})
            except _ResourceBadRequest as exc:
                self._send_json(400, {"ok": False, "error": str(exc)})
            except Exception as exc:
                self._send_json(500, {"ok": False, "error": str(exc)})

        def _yaml_insert(self, config_path, section_key, entry_line, name, _re):
            """Read a YAML config, check for duplicate, insert entry after section header."""
            if not os.path.isfile(config_path):
                raise _ResourceBadRequest(f"config not found: {os.path.basename(config_path)}")
            with open(config_path, "r") as fh:
                config_text = fh.read()
            if _re.search(rf'^  {_re.escape(name)}:', config_text, _re.MULTILINE):
                raise _ResourceConflict(f"resource '{name}' already exists")
            new_lines = []
            inserted = False
            in_section = False
            for line in config_text.splitlines():
                new_lines.append(line)
                if line.strip() == section_key:
                    in_section = True
                    continue
                if in_section and not inserted:
                    new_lines.append(entry_line)
                    inserted = True
                    in_section = False
            if not inserted:
                new_lines.append(entry_line)
            with open(config_path, "w") as fh:
                fh.write("\n".join(new_lines) + "\n")

        def _finish_create(self, kind, name, path_info):
            """Send 201 with refreshed resource map."""
            resources = state.get_profile_resources()
            self._send_json(201, {
                "ok": True,
                "kind": kind,
                "name": name,
                "path": path_info,
                "resources": resources,
            })

        def _create_journal_resource(self, profile_base, name, _re):
            config_path = os.path.join(profile_base, "jrnl.yaml")
            resource_dir = os.path.join(profile_base, "journals")
            resource_file = os.path.join(resource_dir, f"{name}.txt")
            os.makedirs(resource_dir, exist_ok=True)
            if not os.path.isfile(resource_file):
                import time as time_mod
                ts = time_mod.strftime("%Y-%m-%d %H:%M")
                with open(resource_file, "w") as fh:
                    fh.write(f"[{ts}] Welcome to your {name} journal!\n")
            self._yaml_insert(config_path, "journals:", f"  {name}: {resource_file}", name, _re)
            self._finish_create("journals", name, resource_file)

        def _create_ledger_resource(self, profile_base, name, _re):
            config_path = os.path.join(profile_base, "ledgers.yaml")
            resource_dir = os.path.join(profile_base, "ledgers")
            resource_file = os.path.join(resource_dir, f"{name}.journal")
            os.makedirs(resource_dir, exist_ok=True)
            if not os.path.isfile(resource_file):
                with open(resource_file, "w") as fh:
                    fh.write(f"; Hledger journal: {name}\n; Created: {time.strftime('%Y-%m-%d')}\n")
            self._yaml_insert(config_path, "ledgers:", f"  {name}: {resource_file}", name, _re)
            self._finish_create("ledgers", name, resource_file)

        def _create_tasklist_resource(self, profile_base, name, _re):
            config_path = os.path.join(profile_base, "tasklists.yaml")
            task_dir = os.path.join(profile_base, "tasklists", name, ".task")
            hooks_dir = os.path.join(task_dir, "hooks")
            taskrc = os.path.join(profile_base, "tasklists", name, ".taskrc")
            os.makedirs(task_dir, exist_ok=True)
            os.makedirs(hooks_dir, exist_ok=True)
            if not os.path.isfile(taskrc):
                with open(taskrc, "w") as fh:
                    fh.write(f"data.location={task_dir}\nhooks.location={hooks_dir}\nhooks=on\n")
            # Ensure config file exists with section header + default entry
            if not os.path.isfile(config_path):
                with open(config_path, "w") as fh:
                    fh.write("tasklists:\n  default:\n")
                    fh.write(f"    taskrc: {os.path.join(profile_base, '.taskrc')}\n")
                    fh.write(f"    taskdata: {os.path.join(profile_base, '.task')}\n")
            # Check duplicate
            with open(config_path, "r") as fh:
                config_text = fh.read()
            if _re.search(rf'^  {_re.escape(name)}:', config_text, _re.MULTILINE):
                raise _ResourceConflict(f"resource '{name}' already exists")
            # Append new entry at end of file (always inside the tasklists: section)
            entry = f"  {name}:\n    taskrc: {taskrc}\n    taskdata: {task_dir}\n"
            with open(config_path, "a") as fh:
                fh.write(entry)
            self._finish_create("tasklists", name, taskrc)

        def _create_timew_resource(self, profile_base, name, _re):
            config_path = os.path.join(profile_base, "timew.yaml")
            timew_dir = os.path.join(profile_base, "timew", name)
            os.makedirs(timew_dir, exist_ok=True)
            # Ensure config file exists with section header
            if not os.path.isfile(config_path):
                with open(config_path, "w") as fh:
                    fh.write("timew:\n")
                    fh.write(f"  default: {os.path.join(profile_base, '.timewarrior')}\n")
            self._yaml_insert(config_path, "timew:", f"  {name}: {timew_dir}", name, _re)
            self._finish_create("timew", name, timew_dir)

        # -- GET /data/commands ----------------------------------------------

        def _handle_data_commands(self) -> None:
            """
            Parse top-level ww commands from `ww help` output.

            Returns a list of {name, desc} objects for use by the browser
            terminal typeahead. Cached client-side; only fetched once per page load.
            """
            import re as _re
            try:
                result = subprocess.run(
                    [os.path.join(state.ww_base, "bin", "ww"), "help"],
                    capture_output=True, text=True, timeout=10,
                    env={**os.environ, "WW_BASE": state.ww_base},
                )
                commands = []
                in_commands = False
                for line in result.stdout.splitlines():
                    if _re.search(r'commands', line, _re.IGNORECASE) and ':' in line:
                        in_commands = True
                        continue
                    if in_commands:
                        # Command lines: "  name   description text"
                        m = _re.match(r'\s{2,}(\w[\w-]*)\s{2,}(.+)', line)
                        if m:
                            commands.append({
                                "name": m.group(1),
                                "desc": m.group(2).strip(),
                            })
                        elif line.strip() == "" and commands:
                            # Blank line after command block may signal end of section
                            pass
                self._send_json(200, {"ok": True, "commands": commands})
            except Exception:
                self._send_json(200, {"ok": True, "commands": []})

        # -- POST /action ----------------------------------------------------

        def _handle_action(self) -> None:
            """
            Execute a task or journal/ledger/time mutation and return the result.

            Supported actions:
              done, start, stop   — task lifecycle
              add                 — create a new task
              annotate            — add annotation to a task
              journal_add         — append an entry to the profile's journal file
              ledger_add          — append a transaction to the profile's ledger file
              timew_start         — start time tracking with optional tags
              timew_stop          — stop current time tracking
              timew_track         — record a past time interval with duration and tags
            """
            body = self._read_json_body()
            if body is None:
                return
            action = body.get("action", "")
            paths = state.get_profile_paths()
            if not paths:
                self._send_json(400, {"ok": False, "error": "no active profile"})
                return
            env = {**os.environ,
                   "TASKRC": paths["taskrc"],
                   "TASKDATA": paths["taskdata"],
                   "TIMEWARRIORDB": paths["timewarriordb"]}

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
                    self._send_json(200, {"ok": True, "output": (r.stdout or r.stderr).strip(), "tasks": tasks})

                elif action == "start":
                    tid = str(body.get("id", ""))
                    r = run_task(tid, "start")
                    tasks = fetch_tasks()
                    self._send_json(200, {"ok": True, "output": (r.stdout or r.stderr).strip(), "tasks": tasks})

                elif action == "stop":
                    tid = str(body.get("id", ""))
                    r = run_task(tid, "stop")
                    tasks = fetch_tasks()
                    self._send_json(200, {"ok": True, "output": (r.stdout or r.stderr).strip(), "tasks": tasks})

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
                    # Optional journal override — write to a specific named journal
                    journal_name = body.get("args", {}).get("journal", "")
                    target_file = paths["journal_file"]
                    if journal_name:
                        resources = state.get_profile_resources()
                        journals = resources.get("journals", {}) if resources else {}
                        if journal_name in journals:
                            target_file = journals[journal_name]
                    import time as time_mod
                    timestamp = time_mod.strftime("%Y-%m-%d %H:%M")
                    line = f"\n[{timestamp}] {entry_text}\n"
                    with open(target_file, "a") as fh:
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

                elif action == "timew_start":
                    args_obj = body.get("args", {})
                    tags = args_obj.get("tags", "").strip()
                    cmd = ["timew", "start"]
                    if tags:
                        cmd.extend(tags.split())
                    timew_env = {**os.environ, "TIMEWARRIORDB": paths["timewarriordb"]}
                    r = subprocess.run(cmd, capture_output=True, text=True, timeout=10, env=timew_env)
                    self._send_json(200, {"ok": r.returncode == 0, "output": (r.stdout or r.stderr).strip()})

                elif action == "timew_stop":
                    timew_env = {**os.environ, "TIMEWARRIORDB": paths["timewarriordb"]}
                    r = subprocess.run(["timew", "stop"], capture_output=True, text=True, timeout=10, env=timew_env)
                    self._send_json(200, {"ok": r.returncode == 0, "output": (r.stdout or r.stderr).strip()})

                elif action == "timew_track":
                    args_obj = body.get("args", {})
                    tags = args_obj.get("tags", "").strip()
                    duration = args_obj.get("duration", "").strip()
                    if not duration:
                        self._send_json(400, {"ok": False, "error": "duration required (e.g. 30min, 1h)"})
                        return
                    cmd = ["timew", "track", duration]
                    if tags:
                        cmd.extend(tags.split())
                    timew_env = {**os.environ, "TIMEWARRIORDB": paths["timewarriordb"]}
                    r = subprocess.run(cmd, capture_output=True, text=True, timeout=10, env=timew_env)
                    self._send_json(200, {"ok": r.returncode == 0, "output": (r.stdout or r.stderr).strip()})

                elif action == "task_modify":
                    tid = str(body.get("id", ""))
                    mods = body.get("args", {})
                    if not tid:
                        self._send_json(400, {"ok": False, "error": "id required"})
                        return
                    cmd_parts = [tid, "modify"]
                    for k, v in mods.items():
                        if k == "tags_add":
                            for tag in (v if isinstance(v, list) else [v]):
                                cmd_parts.append(f"+{tag}")
                        elif k == "tags_remove":
                            for tag in (v if isinstance(v, list) else [v]):
                                cmd_parts.append(f"-{tag}")
                        elif k == "description":
                            cmd_parts.append(str(v))
                        elif v == "":
                            cmd_parts.append(f"{k}:")
                        else:
                            cmd_parts.append(f"{k}:{v}")
                    r = run_task(*cmd_parts)
                    tasks = fetch_tasks()
                    self._send_json(200, {"ok": r.returncode == 0, "output": (r.stdout or r.stderr).strip(), "tasks": tasks})

                elif action == "task_get":
                    tid = str(body.get("id", ""))
                    if not tid:
                        self._send_json(400, {"ok": False, "error": "id required"})
                        return
                    r = subprocess.run(
                        ["task", "rc.confirmation=no", tid, "export"],
                        capture_output=True, text=True, timeout=10, env=env,
                    )
                    task_list = json.loads(r.stdout) if r.stdout.strip() else []
                    self._send_json(200, {"ok": bool(task_list), "task": task_list[0] if task_list else None})

                elif action == "cmd_log":
                    args_obj = body.get("args", {})
                    entry = args_obj.get("entry", {})
                    if not entry:
                        self._send_json(400, {"ok": False, "error": "entry required"})
                        return
                    log_dir = os.path.join(state.ww_base, "services", "cmd")
                    os.makedirs(log_dir, exist_ok=True)
                    log_path = os.path.join(log_dir, "cmd.log")
                    with open(log_path, "a") as fh:
                        fh.write(json.dumps(entry) + "\n")
                    self._send_json(200, {"ok": True})

                elif action == "ledger_add_account":
                    account_name = body.get("args", {}).get("account", "").strip()
                    if not account_name:
                        self._send_json(400, {"ok": False, "error": "account name required"})
                        return
                    ledger_file = paths["ledger_file"]
                    line = f"\naccount {account_name}\n"
                    with open(ledger_file, "a") as fh:
                        fh.write(line)
                    self._send_json(200, {"ok": True, "output": f"account {account_name} declared"})

                elif action == "q_create_template":
                    args_obj = body.get("args", {})
                    svc = args_obj.get("service", "custom")
                    tname = args_obj.get("name", "").strip()
                    tdesc = args_obj.get("description", "")
                    tquestions = args_obj.get("questions", [])
                    if not tname or not tquestions:
                        self._send_json(400, {"ok": False, "error": "name and questions required"})
                        return
                    profile = state.get_active_profile()
                    if not profile:
                        self._send_json(400, {"ok": False, "error": "no active profile"})
                        return
                    tdir = os.path.join(state.ww_base, "profiles", profile, "services", "questions", "templates", svc)
                    os.makedirs(tdir, exist_ok=True)
                    tpath = os.path.join(tdir, f"{tname}.json")
                    if os.path.isfile(tpath):
                        self._send_json(409, {"ok": False, "error": f"template '{tname}' already exists"})
                        return
                    template = {
                        "name": tname,
                        "description": tdesc,
                        "service": svc,
                        "questions": [{"id": f"q{i+1}", "text": q, "type": "text", "required": i == 0} for i, q in enumerate(tquestions)],
                        "output_format": {"title": f"{tname} - {{date}}", "tags": [svc, "template"]},
                    }
                    with open(tpath, "w") as fh:
                        json.dump(template, fh, indent=2)
                    self._send_json(201, {"ok": True, "path": tpath})

                elif action == "project_create":
                    args_obj = body.get("args", {})
                    pname = args_obj.get("name", "").strip()
                    pdesc = args_obj.get("description", "")
                    if not pname:
                        self._send_json(400, {"ok": False, "error": "project name required"})
                        return
                    import re as _re_p
                    if not _re_p.fullmatch(r'[a-zA-Z0-9_-]+', pname):
                        self._send_json(400, {"ok": False, "error": "name: letters, numbers, hyphens, underscores only"})
                        return
                    projects_yaml = os.path.join(state.ww_base, "config", "projects.yaml")
                    if not os.path.isfile(projects_yaml):
                        with open(projects_yaml, "w") as fh:
                            fh.write("projects:\n")
                    with open(projects_yaml, "r") as fh:
                        content = fh.read()
                    if _re_p.search(rf'^  {_re_p.escape(pname)}:', content, _re_p.MULTILINE):
                        self._send_json(409, {"ok": False, "error": f"project '{pname}' already exists"})
                        return
                    entry = f"  {pname}:\n    description: {pdesc}\n"
                    with open(projects_yaml, "a") as fh:
                        fh.write(entry)
                    self._send_json(201, {"ok": True, "name": pname})

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

    # Initialise heuristic engine
    heuristic_engine = HeuristicEngine(ww_base)
    print(f"Heuristic engine: {len(heuristic_engine.rules)} rules loaded (threshold: {heuristic_engine.threshold})")

    # Build the handler class (closes over state and ww_bin)
    HandlerClass = make_handler(state, ww_bin, heuristic_engine)

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
