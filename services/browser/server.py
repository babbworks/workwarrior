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
  GET  /data/lists    → simple list items (tools/list) for active named list
  GET  /data/ledger   → account balances and recent transactions for active profile
  GET  /data/community/list → JSON list of communities (global .community db)
  GET  /data/community/<name>?view=… → entries for one community (view hint for UI)
  POST /action        → task mutation (incl. list_add/list_finish/list_edit/list_remove; community_add)
  POST /resource/create → create a new named resource (journal/ledger/tasklist/timew/lists)
  GET  /              → minimal placeholder HTML

State files (written on start, removed on clean shutdown):
  $WW_BASE/.state/browser.pid
  $WW_BASE/.state/browser.port

CLI:
  python3 server.py [--port N] [--no-open] [--ww-base PATH]
"""

import argparse
import http.server
import importlib.util
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
from typing import Any
from urllib.parse import parse_qs, unquote, urlparse


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

VERSION = "1.0.0"

# Lazy import of services/community/community_store.py (same tree as this file).
_community_store_mod: Any = "_pending"

# Lazy import of lib/journal_scanner.py
_journal_scanner_mod: Any = "_pending"


def _load_journal_scanner():
    """Return the journal_scanner module, or None if load fails."""
    global _journal_scanner_mod
    if _journal_scanner_mod is None:
        return None
    if _journal_scanner_mod != "_pending":
        return _journal_scanner_mod
    scanner_path = os.path.normpath(
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "lib", "journal_scanner.py")
    )
    if not os.path.isfile(scanner_path):
        _journal_scanner_mod = None
        return None
    try:
        spec = importlib.util.spec_from_file_location("ww_journal_scanner", scanner_path)
        if spec is None or spec.loader is None:
            _journal_scanner_mod = None
            return None
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        _journal_scanner_mod = mod
        return mod
    except Exception:
        _journal_scanner_mod = None
        return None


def _load_community_store():
    """Return the community_store module, or None if load fails."""
    global _community_store_mod
    if _community_store_mod is None:
        return None
    if _community_store_mod != "_pending":
        return _community_store_mod
    store_path = os.path.normpath(
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "community", "community_store.py")
    )
    if not os.path.isfile(store_path):
        _community_store_mod = None
        return None
    try:
        spec = importlib.util.spec_from_file_location("ww_community_store", store_path)
        if spec is None or spec.loader is None:
            _community_store_mod = None
            return None
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        _community_store_mod = mod
        return mod
    except Exception:
        _community_store_mod = None
        return None

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
    "community",
    # management
    "remove",
    # warrior + cross-profile tools
    "warrior", "projects", "network", "saves",
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
        self._active_list: str = "default"

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
          lists:     {name: basename, ...}  — basename is list.py -l value (file in profile/list/)
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
                        m = _re.match(r'^  ([\w-]+):\s*(.+)', line)
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
                        m = _re.match(r'^  ([\w-]+):\s*(.+)', line)
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

        # Simple lists (tools/list) — lists.yaml maps logical name → basename (-l)
        lists_map: dict = {}
        lists_yaml = os.path.join(base, "lists.yaml")
        if os.path.isfile(lists_yaml):
            try:
                content = open(lists_yaml).read()
                in_lists = False
                for line in content.splitlines():
                    if line.strip() == "lists:":
                        in_lists = True
                        continue
                    if in_lists:
                        m = _re.match(r"^  ([a-zA-Z0-9_-]+):\s*([a-zA-Z0-9_-]+)\s*$", line)
                        if m:
                            lists_map[m.group(1)] = m.group(2)
                        elif line and not line.startswith(" "):
                            in_lists = False
            except OSError:
                pass
        if not lists_map:
            lists_map = {"default": "tasks"}

        return {
            "journals":  journals,
            "ledgers":   ledgers,
            "tasklists": tasklists,
            "timew":     timew,
            "lists":     lists_map,
        }

    def get_profile_paths(self) -> dict:
        """
        Return resolved absolute paths for the currently selected resources.
        Respects active_journal / active_ledger / active_tasklist / active_timew / active_list
        session selections. Falls back to 'default' when selection is missing.
        Returns an empty dict when no profile is active.
        """
        resources = self.get_profile_resources()
        if not resources:
            return {}

        profile = self.get_active_profile()
        journals  = resources["journals"]
        ledgers   = resources["ledgers"]
        tasklists = resources["tasklists"]
        timew     = resources["timew"]
        lists_m   = resources.get("lists", {"default": "tasks"})

        journal_key  = self._active_journal  if self._active_journal  in journals  else "default"
        ledger_key   = self._active_ledger   if self._active_ledger   in ledgers   else "default"
        tasklist_key = self._active_tasklist if self._active_tasklist in tasklists else "default"
        timew_key    = self._active_timew    if self._active_timew    in timew     else "default"
        list_key     = self._active_list     if self._active_list     in lists_m   else "default"

        tl = tasklists.get(tasklist_key, tasklists.get("default", {}))
        list_dir = os.path.join(self.ww_base, "profiles", profile, "list")
        list_basename = lists_m.get(list_key, lists_m.get("default", "tasks"))
        return {
            "taskrc":        tl.get("taskrc", ""),
            "taskdata":      tl.get("taskdata", ""),
            "timewarriordb": timew.get(timew_key, timew.get("default", "")),
            "journal_file":  journals.get(journal_key, journals.get("default", "")),
            "ledger_file":   ledgers.get(ledger_key, ledgers.get("default", "")),
            "list_dir":      list_dir,
            "list_basename": list_basename,
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
            self._active_list     = "default"
        return True

    def set_active_resource(self, kind: str, name: str) -> bool:
        """
        Switch the active named resource (journals/ledgers/tasklists/timew/lists).
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
            "lists":     "_active_list",
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
# Simple list tool (tools/list) + TimeWarrior timestamp helper
# ---------------------------------------------------------------------------

def _list_py_script(ww_base: str) -> str:
    return os.path.join(ww_base, "tools", "list", "list.py")


def _run_list_py(ww_base: str, list_dir: str, list_basename: str, extra: list) -> subprocess.CompletedProcess:
    """Invoke bundled list.py with -t and -l (basename). extra are additional argv tokens."""
    cmd = [sys.executable, _list_py_script(ww_base), "-t", list_dir, "-l", list_basename] + list(extra)
    return subprocess.run(cmd, capture_output=True, text=True, timeout=25, env={**os.environ})


def _parse_list_py_stdout(stdout: str) -> list:
    """Parse default `list` output lines: 'prefix - description'."""
    items: list[dict] = []
    for raw in (stdout or "").splitlines():
        line = raw.strip()
        if not line:
            continue
        m = re.match(r"^(\S+)\s+-\s+(.*)$", line)
        if m:
            items.append({"prefix": m.group(1), "text": m.group(2)})
    return items


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
            elif self.path == "/data/tasks" or self.path.startswith("/data/tasks?"):
                self._handle_data_tasks()
            elif self.path == "/data/time":
                self._handle_data_time()
            elif self.path == "/data/journal":
                self._handle_data_journal()
            elif self.path == "/data/lists" or self.path.startswith("/data/lists?"):
                self._handle_data_lists()
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
            elif self.path == "/data/nav-config":
                self._handle_data_nav_config()
            elif self.path == "/data/projects":
                self._handle_data_projects()
            elif self.path.startswith("/data/project/"):
                import urllib.parse as _urlparse
                _pname = _urlparse.unquote(self.path[len("/data/project/"):])
                if _pname:
                    self._handle_data_project_detail(_pname)
                else:
                    self._send_json(400, {"ok": False, "error": "project name required"})
            elif self.path == "/data/tags":
                self._handle_data_tags()
            elif self.path == "/data/task-meta":
                self._handle_data_task_meta()
            elif self.path == "/data/udas":
                self._handle_data_udas()
            elif self.path == "/data/sync":
                self._handle_data_sync()
            elif self.path == "/data/models":
                self._handle_data_models()
            elif self.path == "/data/questions":
                self._handle_data_questions()
            elif self.path.startswith("/data/profile-detail"):
                self._handle_data_profile_detail()
            elif self.path == "/data/warrior":
                self._handle_data_warrior()
            elif self.path.startswith("/data/community/"):
                self._handle_data_community_path()
            elif self.path == "/data/warlock/status":
                self._handle_data_warlock_status()
            elif self.path == "/export/snapshot":
                self._handle_export_snapshot()
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
            """Return pending/active (default) or completed (done=1) tasks for the active profile."""
            paths = state.get_profile_paths()
            if not paths:
                self._send_json(200, {"ok": False, "error": "no active profile", "tasks": []})
                return
            qs = parse_qs(urlparse(self.path).query)
            show_done = qs.get('done', [''])[0] == '1'
            env = {**os.environ, "TASKRC": paths["taskrc"], "TASKDATA": paths["taskdata"]}
            try:
                if show_done:
                    result = subprocess.run(
                        ["task", "rc.confirmation=no", "status:completed", "export"],
                        capture_output=True, text=True, timeout=10, env=env,
                    )
                    tasks = json.loads(result.stdout) if result.stdout.strip() else []
                    tasks.sort(key=lambda t: t.get("end", t.get("modified", "")), reverse=True)
                    self._send_json(200, {"ok": True, "tasks": tasks, "done": True})
                else:
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
            prev2_month = time.strftime("%Y-%m", time.gmtime(time.time() - 65 * 86400))
            active_interval = None
            for month in [prev2_month, prev_month, current_month]:
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

            # Assign timew @N IDs (1 = most recent = last in list)
            total = len(intervals)
            for i, iv in enumerate(intervals):
                iv["timew_id"] = total - i

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
                "intervals": intervals,  # full history for client-side week navigation
                "today_total_seconds": today_total,
                "week_total_seconds": week_total,
                "active": active_interval is not None,
                "active_tags": active_interval["tags"] if active_interval else None,
                "active_since": active_interval["start"] if active_interval else None,
            })

        # -- GET /data/journal -----------------------------------------------

        def _handle_data_journal(self) -> None:
            """
            Read the profile's journal text file and return entries with annotations split.
            Uses journal_scanner when available; falls back to plain parse.
            Entry headers have the format: [YYYY-MM-DD HH:MM]
            """
            paths = state.get_profile_paths()
            if not paths:
                self._send_json(200, {"ok": False, "error": "no active profile", "entries": []})
                return
            journal_file = paths["journal_file"]
            scanner = _load_journal_scanner()
            if scanner:
                try:
                    entries = scanner.parse_file(journal_file)
                    self._send_json(200, {"ok": True, "entries": entries, "total": len(entries)})
                    return
                except Exception:
                    pass
            # Fallback: plain parse without annotation splitting
            try:
                import re as _re
                content = open(journal_file).read()
                parts = _re.split(r'\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\]', content)
                entries = []
                for i in range(1, len(parts) - 1, 2):
                    date = parts[i]
                    body = parts[i + 1].strip()
                    if body:
                        entries.append({"date": date, "date_slug": date.replace(' ', '_').replace(':', '-'), "body": body, "annotations": []})
                entries.reverse()
                self._send_json(200, {"ok": True, "entries": entries, "total": len(entries)})
            except OSError:
                self._send_json(200, {"ok": True, "entries": []})

        # -- GET /data/lists -------------------------------------------------

        def _handle_data_lists(self) -> None:
            """Return open items from the active simple list via tools/list/list.py."""
            paths = state.get_profile_paths()
            if not paths:
                self._send_json(200, {"ok": False, "error": "no active profile", "items": []})
                return
            list_dir = paths.get("list_dir", "")
            list_basename = paths.get("list_basename", "tasks")
            if not list_dir:
                self._send_json(200, {"ok": False, "error": "no list directory", "items": []})
                return
            try:
                os.makedirs(list_dir, exist_ok=True)
            except OSError:
                pass
            qs = parse_qs(urlparse(self.path).query)
            show_done = qs.get('done', [''])[0] == '1'
            extra = ['--done'] if show_done else []
            r = _run_list_py(state.ww_base, list_dir, list_basename, extra)
            if r.returncode != 0:
                err = (r.stderr or r.stdout or "list failed").strip()
                self._send_json(200, {"ok": False, "error": err, "items": []})
                return
            items = _parse_list_py_stdout(r.stdout or "")
            self._send_json(200, {
                "ok": True,
                "items": items,
                "list_basename": list_basename,
                "active_list": state._active_list,
            })

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
                        # format: "          $1,234.56  account:name" or "  10 h  time:work"
                        m = _re.match(r'^\s+(.*?\S)\s{2,}(\S.*)', line)
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
                    for line in data_lines:
                        parts = line.split('\t')
                        if len(parts) >= 6:
                            recent.append({
                                "date":        parts[1],
                                "description": parts[3],
                                "account":     parts[4],
                                "amount":      parts[5],
                                "balance":     parts[6] if len(parts) > 6 else "",
                            })
                    # Deduplicate: hledger register outputs one row per posting;
                    # keep only the first occurrence of each (date, description) pair
                    seen_tx: set = set()
                    deduped: list = []
                    for item in recent:
                        key = (item['date'], item['description'])
                        if key not in seen_tx:
                            seen_tx.add(key)
                            deduped.append(item)
                    recent = deduped[-15:]
                # Parse annotations and per-transaction tags from raw file
                annotations: list = []
                tx_meta: dict = {}  # "date|desc" → {project, tags, priority, task_uuid}
                try:
                    with open(ledger_file, "r") as fh:
                        raw_lines = fh.readlines()
                    i = 0
                    while i < len(raw_lines):
                        raw = raw_lines[i].rstrip()
                        # Top-level annotation: ; [YYYY-MM-DD] desc: note
                        am = _re.match(r'^;\s*\[(\d{4}-\d{2}-\d{2})\]\s*(.*?):\s*(.+)$', raw)
                        if am:
                            annotations.append({
                                "date":        am.group(1),
                                "description": am.group(2).strip(),
                                "note":        am.group(3).strip(),
                            })
                            i += 1
                            continue
                        # Transaction header: YYYY-MM-DD [* or !] description
                        tm = _re.match(r'^(\d{4}-\d{2}-\d{2})[=\d-]*\s+[*!]?\s*(.*)', raw)
                        if tm:
                            tx_date = tm.group(1)
                            tx_desc = _re.sub(r'^\([^)]+\)\s*', '', tm.group(2)).strip()
                            proj = ''
                            tags_list: list = []
                            priority = ''
                            task_uuid = ''
                            j = i + 1
                            while j < len(raw_lines):
                                pline = raw_lines[j].rstrip()
                                if not pline or (pline and not pline[0].isspace()):
                                    break
                                cm = _re.match(r'\s+;\s*(.*)', pline)
                                if cm:
                                    ct = cm.group(1)
                                    pm = _re.search(r'\bproject:(\S+)', ct)
                                    if pm:
                                        proj = pm.group(1)
                                    prm = _re.search(r'\bpriority:([HMLhml])', ct)
                                    if prm:
                                        priority = prm.group(1).upper()
                                    tum = _re.search(r'\btask:([0-9a-f-]{36})', ct)
                                    if tum:
                                        task_uuid = tum.group(1)
                                    for tg in _re.finditer(r'\btag:(\S+)', ct):
                                        tags_list.append(tg.group(1))
                                j += 1
                            if proj or tags_list or priority or task_uuid:
                                tx_meta[f"{tx_date}|{tx_desc}"] = {
                                    "project": proj, "tags": tags_list,
                                    "priority": priority, "task_uuid": task_uuid,
                                }
                            i = j
                            continue
                        i += 1
                except OSError:
                    pass
                # Attach project/tags/priority/task_uuid to recent items
                for item in recent:
                    key = f"{item['date']}|{item['description']}"
                    meta = tx_meta.get(key, {})
                    item["project"]   = meta.get("project", "")
                    item["tags"]      = meta.get("tags", [])
                    item["priority"]  = meta.get("priority", "")
                    item["task_uuid"] = meta.get("task_uuid", "")
                self._send_json(200, {"ok": True, "balances": balances, "recent": recent,
                                      "annotations": annotations})
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
                # Merge cross-profile inventory if available
                inv_path = os.path.join(state.ww_base, "resources", "inventory", "ledger-accounts.yaml")
                if os.path.isfile(inv_path):
                    try:
                        import re as _rein
                        inv_text = open(inv_path).read()
                        inv_accounts = _rein.findall(r'^\s+-\s+"?([^"\n]+)"?', inv_text, _rein.MULTILINE)
                        merged = sorted(set(accounts) | set(a.strip() for a in inv_accounts))
                        accounts = merged
                    except Exception:
                        pass
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

        # -- GET /data/sync --------------------------------------------------

        def _handle_data_sync(self) -> None:
            """
            Return sync dashboard state for the active profile.
            Reads bugwarrior config to detect configuration, and checks
            the github-sync state.json for last sync timestamps.
            """
            paths = state.get_profile_paths()
            if not paths:
                self._send_json(200, {"ok": True, "configured": False, "error": "no active profile"})
                return
            profile = state.get_active_profile() or "—"
            ww_base = paths.get("base", "")
            # Check for bugwarrior config (.bugwarriorrc in profile base)
            bw_config = os.path.join(ww_base, ".bugwarriorrc")
            configured = os.path.isfile(bw_config)
            repo = None
            if configured:
                try:
                    import re as _re
                    content = open(bw_config).read()
                    m = _re.search(r'project_name\s*=\s*(.+)', content)
                    if m:
                        repo = m.group(1).strip()
                except Exception:
                    pass
            # Check github-sync state file for last push/pull timestamps
            state_file = os.path.join(ww_base, ".task", "github-sync", "state.json")
            last_push = None
            last_pull = None
            pending_push = 0
            if os.path.isfile(state_file):
                try:
                    with open(state_file) as fh:
                        sync_data = json.load(fh)
                    meta = sync_data.get("_meta", {})
                    last_push = meta.get("last_push")
                    last_pull = meta.get("last_pull")
                    # Count tasks with dirty flag (pending push)
                    for k, v in sync_data.items():
                        if k.startswith("_"):
                            continue
                        if isinstance(v, dict) and v.get("dirty"):
                            pending_push += 1
                except Exception:
                    pass
            self._send_json(200, {
                "ok": True,
                "configured": configured,
                "profile": profile,
                "repo": repo,
                "last_push": last_push,
                "last_pull": last_pull,
                "pending_push": pending_push,
            })

        # -- GET /data/models ------------------------------------------------

        def _handle_data_models(self) -> None:
            """
            Parse config/models.yaml and return structured model list.
            Returns [{name, provider, model_id, notes, active}] where
            active indicates the current default model.
            """
            models_yaml = os.path.join(state.ww_base, "config", "models.yaml")
            if not os.path.isfile(models_yaml):
                self._send_json(200, {"ok": True, "models": [], "default": None})
                return
            try:
                import re as _re
                content = open(models_yaml).read()
                # Parse default
                dm = _re.search(r'^\s*default:\s*(.+)$', content, _re.MULTILINE)
                default_name = dm.group(1).strip() if dm else None
                # Parse model blocks: find models: section, then each key
                models = []
                in_models = False
                in_providers = False
                current_name = None
                current = {}
                for line in content.splitlines():
                    if line.startswith('models:'):
                        in_models = True
                        in_providers = False
                        continue
                    if line.startswith('providers:'):
                        # flush last model
                        if current_name and current_name != 'default':
                            models.append({**current, "name": current_name})
                        in_providers = True
                        in_models = False
                        current_name = None
                        current = {}
                        continue
                    if in_models:
                        # top-level model name key (2-space indent key:)
                        m = _re.match(r'^  (\w[\w\-_]*):\s*$', line)
                        if m:
                            if current_name and current_name != 'default':
                                models.append({**current, "name": current_name})
                            current_name = m.group(1)
                            current = {}
                            continue
                        # nested key: value under model
                        kv = _re.match(r'^    (\w+):\s*(.+)$', line)
                        if kv and current_name:
                            current[kv.group(1)] = kv.group(2).strip().strip('"')
                # flush last
                if current_name and current_name != 'default' and in_models:
                    models.append({**current, "name": current_name})
                # Annotate default
                for m in models:
                    m["active"] = (m["name"] == default_name)
                    m.setdefault("provider", "unknown")
                    m.setdefault("id", "")
                    m.setdefault("notes", "")
                self._send_json(200, {"ok": True, "models": models, "default": default_name})
            except Exception as ex:
                self._send_json(200, {"ok": False, "models": [], "error": str(ex)})

        # -- GET /data/questions ---------------------------------------------

        def _handle_data_questions(self) -> None:
            """
            Scan services/questions/templates/<service>/*.json and return
            [{name, service, description, questions:[{id,text,type,required}]}]
            """
            templates_dir = os.path.join(state.ww_base, "services", "questions", "templates")
            if not os.path.isdir(templates_dir):
                self._send_json(200, {"ok": True, "templates": []})
                return
            templates = []
            for service in sorted(os.listdir(templates_dir)):
                svc_dir = os.path.join(templates_dir, service)
                if not os.path.isdir(svc_dir):
                    continue
                for fname in sorted(os.listdir(svc_dir)):
                    if not fname.endswith(".json"):
                        continue
                    try:
                        with open(os.path.join(svc_dir, fname)) as fh:
                            t = json.load(fh)
                        templates.append({
                            "name": t.get("name", fname[:-5]),
                            "file": fname[:-5],
                            "service": service,
                            "description": t.get("description", ""),
                            "questions": t.get("questions", []),
                        })
                    except Exception:
                        pass
            self._send_json(200, {"ok": True, "templates": templates})

        # -- GET /data/profile-detail ----------------------------------------

        def _handle_data_profile_detail(self) -> None:
            """
            Return stat counts for the requested profile name.
            Query param: ?profile=<name>   (defaults to active profile)
            """
            from urllib.parse import urlparse, parse_qs
            qs = parse_qs(urlparse(self.path).query)
            profile_name = (qs.get("profile", [None])[0]) or state.get_active_profile()
            if not profile_name:
                self._send_json(200, {"ok": False, "error": "no profile"})
                return
            profile_dir = os.path.join(state.ww_base, "profiles", profile_name)
            if not os.path.isdir(profile_dir):
                self._send_json(200, {"ok": False, "error": f"profile not found: {profile_name}"})
                return
            import re as _re
            result = {"ok": True, "name": profile_name, "task_count": 0, "journal_count": 0,
                      "ledger_count": 0, "timew_hours": 0.0, "uda_count": 0}
            # Task count via taskchampion sqlite — check both task/ and .task/ subdirs
            for task_subdir in ["task", ".task"]:
                task_db = os.path.join(profile_dir, task_subdir, "taskchampion.sqlite3")
                if os.path.isfile(task_db):
                    try:
                        import sqlite3
                        conn = sqlite3.connect(f"file:{task_db}?mode=ro", uri=True, timeout=2)
                        cur = conn.execute("SELECT COUNT(*) FROM tasks WHERE data LIKE '%\"status\":\"pending\"%' OR data LIKE '%\"status\":\"active\"%'")
                        result["task_count"] = cur.fetchone()[0]
                        conn.close()
                    except Exception:
                        pass
                    break
            # Also check tasklists.yaml for a configured taskdata path
            if result["task_count"] == 0:
                tasklists_yaml = os.path.join(profile_dir, "tasklists.yaml")
                if os.path.isfile(tasklists_yaml):
                    try:
                        content = open(tasklists_yaml).read()
                        m = _re.search(r'^\s+taskdata:\s*(.+)$', content, _re.MULTILINE)
                        if m:
                            td = m.group(1).strip()
                            db = os.path.join(td, "taskchampion.sqlite3")
                            if os.path.isfile(db):
                                import sqlite3
                                conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=2)
                                cur = conn.execute("SELECT COUNT(*) FROM tasks WHERE data LIKE '%\"status\":\"pending\"%' OR data LIKE '%\"status\":\"active\"%'")
                                result["task_count"] = cur.fetchone()[0]
                                conn.close()
                    except Exception:
                        pass
            # Journal count — find journal files from jrnl.yaml or default {profile}.txt
            journal_files = []
            jrnl_yaml = os.path.join(profile_dir, "jrnl.yaml")
            if os.path.isfile(jrnl_yaml):
                try:
                    for line in open(jrnl_yaml):
                        m = _re.match(r'^\s+\w+:\s*(.+\.txt)', line)
                        if m and os.path.isfile(m.group(1).strip()):
                            journal_files.append(m.group(1).strip())
                except Exception:
                    pass
            if not journal_files:
                # Default: {profile}.txt inside journals/
                default_j = os.path.join(profile_dir, "journals", f"{profile_name}.txt")
                if os.path.isfile(default_j):
                    journal_files.append(default_j)
                else:
                    # Fallback: any .txt in journals/
                    jdir = os.path.join(profile_dir, "journals")
                    if os.path.isdir(jdir):
                        for f in os.listdir(jdir):
                            if f.endswith(".txt"):
                                journal_files.append(os.path.join(jdir, f))
            for jf in journal_files:
                try:
                    content = open(jf).read()
                    result["journal_count"] += len(_re.findall(r'\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}\]', content))
                except Exception:
                    pass
            # UDA count from .taskrc
            taskrc = os.path.join(profile_dir, ".taskrc")
            if not os.path.isfile(taskrc):
                taskrc = os.path.join(profile_dir, "task", ".taskrc")
            if not os.path.isfile(taskrc):
                taskrc = os.path.join(profile_dir, ".task", ".taskrc")
            if os.path.isfile(taskrc):
                try:
                    uda_names = set()
                    for line in open(taskrc):
                        m = _re.match(r'^uda\.([^.]+)\.', line.strip())
                        if m:
                            uda_names.add(m.group(1))
                    result["uda_count"] = len(uda_names)
                except Exception:
                    pass
            # Creation date from profile dir mtime
            try:
                import datetime
                mtime = os.path.getmtime(profile_dir)
                result["created"] = datetime.datetime.fromtimestamp(mtime).strftime("%Y-%m-%d")
            except Exception:
                result["created"] = "—"
            # File/settings info
            files = {}
            # taskrc path
            taskrc_found = None
            for tc_path in [os.path.join(profile_dir, ".taskrc"),
                            os.path.join(profile_dir, "task", ".taskrc"),
                            os.path.join(profile_dir, ".task", ".taskrc")]:
                if os.path.isfile(tc_path):
                    taskrc_found = tc_path
                    break
            files["taskrc"] = taskrc_found
            # task data dir
            task_data_dir = None
            for td in [".task", "task"]:
                p = os.path.join(profile_dir, td)
                if os.path.isdir(p):
                    task_data_dir = p
                    break
            files["task_data"] = task_data_dir
            # timew db
            timew_db = os.path.join(profile_dir, ".timewarrior")
            files["timew_db"] = timew_db if os.path.isdir(timew_db) else None
            # journals (name -> path from jrnl.yaml, or default)
            journals_map = {}
            if os.path.isfile(jrnl_yaml):
                try:
                    for line in open(jrnl_yaml):
                        m = _re.match(r'^\s+(\w+):\s*(.+\.txt)', line)
                        if m:
                            journals_map[m.group(1)] = m.group(2).strip()
                except Exception:
                    pass
            if not journals_map:
                default_j = os.path.join(profile_dir, "journals", f"{profile_name}.txt")
                if os.path.isfile(default_j):
                    journals_map["default"] = default_j
            files["journals"] = journals_map
            # ledgers (name -> path from ledgers.yaml)
            ledgers_map = {}
            ledgers_yaml = os.path.join(profile_dir, "ledgers.yaml")
            if os.path.isfile(ledgers_yaml):
                try:
                    for line in open(ledgers_yaml):
                        m = _re.match(r'^\s+(\w+):\s*(.+)', line)
                        if m:
                            ledgers_map[m.group(1)] = m.group(2).strip()
                except Exception:
                    pass
            files["ledgers"] = ledgers_map
            result["files"] = files
            self._send_json(200, result)

        # -- GET /data/warrior -----------------------------------------------

        def _handle_data_warrior(self) -> None:
            """
            Aggregate task stats for all profiles.
            Returns [{name, task_count, active_count, top_task}] + aggregate totals.
            Reads taskchampion sqlite for fast counts without spawning task processes.
            """
            profiles_base = os.path.join(state.ww_base, "profiles")
            if not os.path.isdir(profiles_base):
                self._send_json(200, {"ok": True, "profiles": [], "total_tasks": 0, "total_active": 0})
                return
            results = []
            total_tasks = 0
            total_active = 0
            for pname in sorted(os.listdir(profiles_base)):
                pdir = os.path.join(profiles_base, pname)
                if not os.path.isdir(pdir):
                    continue
                # Try taskchampion sqlite (fast) — check .task/, task/, and tasklists.yaml
                import sqlite3 as _sq3
                import json as _json
                import re as _re2
                task_count = 0
                active_count = 0
                top_task = None

                def _count_tc_db(db_path):
                    nonlocal task_count, active_count, top_task
                    tc = 0; ac = 0; top_urg = -999; top = None
                    try:
                        conn = _sq3.connect(f"file:{db_path}?mode=ro", uri=True, timeout=2)
                        rows = conn.execute("SELECT data FROM tasks WHERE data NOT NULL").fetchall()
                        conn.close()
                        for (data_str,) in rows:
                            try:
                                t = _json.loads(data_str)
                                st = t.get("status", "")
                                if st in ("pending", "active"):
                                    tc += 1
                                if st == "active":
                                    ac += 1
                                urg = float(t.get("urgency", 0))
                                if st in ("pending", "active") and urg > top_urg:
                                    top_urg = urg
                                    top = t.get("description", "")[:60]
                            except Exception:
                                pass
                        task_count += tc; active_count += ac
                        if top and (top_task is None or tc > 0):
                            top_task = top
                        return True
                    except Exception:
                        return False

                found = False
                for task_subdir in [".task", "task"]:
                    db = os.path.join(pdir, task_subdir, "taskchampion.sqlite3")
                    if os.path.isfile(db):
                        found = _count_tc_db(db)
                        break
                if not found:
                    # Check tasklists.yaml for configured taskdata paths
                    tly = os.path.join(pdir, "tasklists.yaml")
                    if os.path.isfile(tly):
                        try:
                            for line in open(tly):
                                m = _re2.match(r'^\s+taskdata:\s*(.+)', line)
                                if m:
                                    db = os.path.join(m.group(1).strip(), "taskchampion.sqlite3")
                                    if os.path.isfile(db):
                                        _count_tc_db(db)
                                        break
                        except Exception:
                            pass
                total_tasks += task_count
                total_active += active_count
                results.append({
                    "name": pname,
                    "task_count": task_count,
                    "active_count": active_count,
                    "top_task": top_task,
                    "is_active": (pname == state.get_active_profile()),
                })
            _ap = state.get_active_profile()
            self._send_json(200, {
                "ok": True,
                "profiles": results,
                "total_tasks": total_tasks,
                "total_active": total_active,
                "active_profile": _ap,
            })

        # -- GET /data/community/* ------------------------------------------

        def _resolve_task_live_state(self, source_ref: str) -> dict | None:
            """Fetch current task data for a source_ref of form {profile}.task.{uuid}.
            Returns the task dict or None if unavailable."""
            import re as _re
            m = _re.match(r'^([^.]+)\.task\.(.+)$', source_ref)
            if not m:
                return None
            profile_name, uuid = m.group(1), m.group(2)
            base = os.path.join(state.ww_base, "profiles", profile_name)
            if not os.path.isdir(base):
                return None
            # Resolve taskrc/taskdata for this profile
            import re as _re2
            taskrc = os.path.join(base, ".taskrc")
            taskdata = os.path.join(base, ".task")
            tasklists_yaml = os.path.join(base, "tasklists.yaml")
            if os.path.isfile(tasklists_yaml):
                try:
                    content = open(tasklists_yaml).read()
                    in_section = False
                    for line in content.splitlines():
                        if line.strip() == "tasklists:":
                            in_section = True
                            continue
                        if in_section:
                            m2 = _re2.match(r'^    (taskrc|taskdata):\s*(.+)', line)
                            if m2:
                                if m2.group(1) == "taskrc":
                                    taskrc = m2.group(2).strip()
                                else:
                                    taskdata = m2.group(2).strip()
                except OSError:
                    pass
            try:
                env = {**os.environ, "TASKRC": taskrc, "TASKDATA": taskdata}
                r = subprocess.run(
                    ["task", "rc.confirmation=no", uuid, "export"],
                    capture_output=True, text=True, timeout=5, env=env,
                )
                tasks = json.loads(r.stdout) if r.stdout.strip() else []
                return tasks[0] if tasks else None
            except Exception:
                return None

        def _community_shell_json(self, args: list, with_live_state: bool = False) -> dict:
            """List/show communities via community_store (in-process)."""
            mod = _load_community_store()
            if mod is None:
                return {"ok": False, "error": "community_store unavailable", "communities": []}
            try:
                if args == ["list"]:
                    return mod.list_communities(state.ww_base)
                if len(args) == 2 and args[0] == "show":
                    result = mod.show_community(state.ww_base, args[1])
                    if with_live_state and result.get("ok"):
                        for entry in result.get("entries", []):
                            if ".task." in entry.get("source_ref", ""):
                                entry["live_state"] = self._resolve_task_live_state(entry["source_ref"])
                            else:
                                entry["live_state"] = None
                    return result
                if len(args) == 3 and args[0] == "entry":
                    # Single entry with live state: args = ["entry", name, entry_id]
                    result = mod.show_community(state.ww_base, args[1])
                    if not result.get("ok"):
                        return result
                    try:
                        eid = int(args[2])
                    except (ValueError, TypeError):
                        return {"ok": False, "error": "invalid entry id"}
                    entries = [e for e in result.get("entries", []) if e["id"] == eid]
                    if not entries:
                        return {"ok": False, "error": "entry not found"}
                    entry = entries[0]
                    if ".task." in entry.get("source_ref", ""):
                        entry["live_state"] = self._resolve_task_live_state(entry["source_ref"])
                    else:
                        entry["live_state"] = None
                    return {"ok": True, "entry": entry}
            except Exception as exc:
                return {"ok": False, "error": str(exc), "communities": []}
            return {"ok": False, "error": "bad community request", "communities": []}

        def _handle_data_community_path(self) -> None:
            """GET /data/community/list or /data/community/<name>?view=…
               or /data/community/<name>/entry/<id>"""
            parsed = urlparse(self.path)
            tail = unquote(parsed.path[len("/data/community/"):].strip("/"))
            qs = parse_qs(parsed.query)
            view = (qs.get("view", ["unified"])[0] or "unified").lower()
            if view not in ("unified", "journal", "tasks", "comments"):
                view = "unified"
            if not tail or tail == "list":
                body = self._community_shell_json(["list"])
                self._send_json(200, body)
                return
            # Handle <name>/entry/<id>
            parts = tail.split("/")
            if len(parts) == 3 and parts[1] == "entry":
                body = self._community_shell_json(["entry", parts[0], parts[2]])
                self._send_json(200, body)
                return
            if len(parts) != 1:
                self._send_json(400, {"ok": False, "error": "invalid community path"})
                return
            body = self._community_shell_json(["show", tail], with_live_state=True)
            body["view"] = view
            self._send_json(200, body)

        # -- GET /data/warlock/status ----------------------------------------

        def _handle_data_warlock_status(self) -> None:
            """Read warlock PID file and .ww-config; return status JSON."""
            warlock_dir = os.path.join(state.ww_base, "tools", "warlock")
            config_path = os.path.join(warlock_dir, ".ww-config")
            pid_path    = os.path.join(warlock_dir, "server.pid")

            cfg: dict[str, str] = {}
            if os.path.isfile(config_path):
                for line in open(config_path).read().splitlines():
                    if "=" in line:
                        k, _, v = line.partition("=")
                        cfg[k.strip()] = v.strip()

            installed = bool(cfg)
            method    = cfg.get("method", "")
            tag       = cfg.get("tag", "")
            port      = cfg.get("port", "5001")
            inst_date = cfg.get("installed", "")

            running = False
            pid_str = ""
            profile = ""
            running_port = ""
            if os.path.isfile(pid_path):
                parts = open(pid_path).read().strip().split()
                if len(parts) >= 3:
                    pid_str, profile, running_port = parts[0], parts[1], parts[2]
                    try:
                        os.kill(int(pid_str), 0)
                        running = True
                    except (OSError, ValueError):
                        pass

            body = {
                "installed": installed,
                "method": method,
                "tag": tag,
                "port": int(running_port or port),
                "installed_date": inst_date,
                "running": running,
                "pid": pid_str,
                "profile": profile,
                "upstream": "https://github.com/jonestristand/task-warlock",
                "attribution": "jonestristand MIT",
            }
            self._send_json(200, body)

        # -- GET /data/projects ---------------------------------------------

        def _handle_data_projects(self) -> None:
            """Return merged project data: auto-discovered from TW + yaml definitions."""
            import re as _re_p

            paths = state.get_profile_paths()

            # 1. Auto-discover projects from active TW profile
            tw_projects: list[str] = []
            env: dict = {}
            if paths:
                env = {**os.environ,
                       "TASKRC": paths["taskrc"],
                       "TASKDATA": paths["taskdata"]}
                try:
                    r = subprocess.run(["task", "_projects"],
                                       capture_output=True, text=True, timeout=5, env=env)
                    tw_projects = [p.strip() for p in r.stdout.splitlines() if p.strip()]
                except Exception:
                    pass

            # 2. Load yaml definitions (description overrides only)
            yaml_defs: dict = {}
            projects_yaml = os.path.join(state.ww_base, "config", "projects.yaml")
            if os.path.isfile(projects_yaml):
                try:
                    current = ""
                    for line in open(projects_yaml).read().splitlines():
                        m = _re_p.match(r'^  ([\w-]+):\s*$', line)
                        if m:
                            current = m.group(1)
                            yaml_defs.setdefault(current, {"description": ""})
                            continue
                        if current:
                            km = _re_p.match(r'^\s+description:\s*(.*)', line)
                            if km and km.group(1).strip():
                                yaml_defs[current]["description"] = km.group(1).strip()
                except Exception:
                    pass

            # 3. Merge: union of TW-discovered and yaml-defined, preserving order
            all_names = list(dict.fromkeys(tw_projects + list(yaml_defs.keys())))

            # 4. Per-project data helpers
            def task_stats(name: str) -> dict:
                if not paths:
                    return {"pending": 0, "done": 0, "active": 0, "next": None, "master": None}
                try:
                    rp = subprocess.run(
                        ["task", "rc.confirmation=no", f"project:{name}",
                         "status:pending", "or", "status:active", "export"],
                        capture_output=True, text=True, timeout=10, env=env)
                    pending_tasks = json.loads(rp.stdout) if rp.stdout.strip() else []
                except Exception:
                    pending_tasks = []
                try:
                    rc = subprocess.run(
                        ["task", "rc.confirmation=no", f"project:{name}",
                         "status:completed", "count"],
                        capture_output=True, text=True, timeout=5, env=env)
                    done = int(rc.stdout.strip()) if rc.stdout.strip().isdigit() else 0
                except Exception:
                    done = 0
                active = [t for t in pending_tasks if t.get("status") == "active"]
                pending = [t for t in pending_tasks if t.get("status") == "pending"]
                master = next(
                    (t for t in pending_tasks if t.get("projectrole") == "master"),
                    None)
                nxt = None
                non_master_pending = [t for t in pending if t.get("projectrole") != "master"]
                if non_master_pending:
                    nxt = max(non_master_pending, key=lambda t: t.get("urgency") or 0)
                return {
                    "pending": len(pending),
                    "done": done,
                    "active": len(active),
                    "next": {
                        "id": nxt.get("id"), "uuid": nxt.get("uuid"),
                        "description": nxt.get("description", ""),
                        "urgency": round(nxt.get("urgency") or 0, 1),
                    } if nxt else None,
                    "master": {
                        "id": master.get("id"), "uuid": master.get("uuid"),
                        "description": master.get("description", ""),
                        "status": master.get("status", ""),
                    } if master else None,
                }

            def journal_stats(name: str) -> dict:
                if not paths:
                    return {"count": 0, "last_date": ""}
                journal_file = paths.get("journal_file", "")
                if not journal_file or not os.path.isfile(journal_file):
                    return {"count": 0, "last_date": ""}
                scanner_path = os.path.normpath(
                    os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                 "..", "..", "lib", "journal_scanner.py"))
                if not os.path.isfile(scanner_path):
                    return {"count": 0, "last_date": ""}
                try:
                    r = subprocess.run(
                        ["python3", scanner_path, "project-stats", journal_file, name],
                        capture_output=True, text=True, timeout=8)
                    d = json.loads(r.stdout) if r.stdout.strip() else {}
                    return {"count": d.get("count", 0), "last_date": d.get("last_date", "")}
                except Exception:
                    return {"count": 0, "last_date": ""}

            def ledger_stats(name: str) -> dict:
                if not paths:
                    return {"count": 0, "amounts": []}
                ledger_file = paths.get("ledger_file", "")
                if not ledger_file or not os.path.isfile(ledger_file):
                    return {"count": 0, "amounts": []}
                try:
                    import re as _re_ls
                    with open(ledger_file, "r") as fh:
                        raw_lines = fh.readlines()
                    count = 0
                    # collect unique amounts per account for project-tagged transactions
                    tx_amounts: list[str] = []
                    i = 0
                    while i < len(raw_lines):
                        raw = raw_lines[i].rstrip()
                        tm = _re_ls.match(r'^(\d{4}-\d{2}-\d{2})', raw)
                        if tm:
                            # scan ahead in transaction block for meta comment
                            j = i + 1
                            proj_match = False
                            block_amounts: list[str] = []
                            while j < len(raw_lines):
                                pline = raw_lines[j].rstrip()
                                if not pline.strip() or (pline.strip() and not pline[0].isspace()):
                                    break
                                cm = _re_ls.match(r'\s+;\s*(.*)', pline)
                                if cm and f"project:{name}" in cm.group(1):
                                    proj_match = True
                                pm = _re_ls.match(r'\s+\S.*\s{2,}(\S+.*)', pline)
                                if pm and not pline.strip().startswith(';'):
                                    block_amounts.append(pm.group(1).strip())
                                j += 1
                            if proj_match:
                                count += 1
                                tx_amounts.extend(block_amounts)
                            i = j
                        else:
                            i += 1
                    # Deduplicate and summarise amounts (first 3)
                    return {"count": count, "amounts": list(dict.fromkeys(tx_amounts))[:4]}
                except Exception:
                    return {"count": 0, "amounts": []}

            # 5. Build response
            projects: dict = {}
            for name in all_names:
                projects[name] = {
                    "description": yaml_defs.get(name, {}).get("description", ""),
                    "from_yaml": name in yaml_defs,
                    "tasks": task_stats(name),
                    "journal": journal_stats(name),
                    "ledger": ledger_stats(name),
                    "timew": None,
                }

            self._send_json(200, {"ok": True, "projects": projects})

        # -- GET /data/project/<name> ---------------------------------------

        def _handle_data_project_detail(self, name: str) -> None:
            """Return full task list, journal entries, and ledger transactions for one project."""
            paths = state.get_profile_paths()
            if not paths:
                self._send_json(200, {"ok": False, "error": "no active profile"})
                return

            env = {**os.environ, "TASKRC": paths["taskrc"], "TASKDATA": paths["taskdata"]}

            # Full task list — two queries avoids ambiguous 'or' filter syntax
            tasks_out: dict = {"active": [], "pending": [], "pending_total": 0, "done": 0, "master": None, "done_list": []}
            try:
                rp = subprocess.run(
                    ["task", "rc.confirmation=no", f"project:{name}", "status:pending", "export"],
                    capture_output=True, text=True, timeout=10, env=env)
                ra = subprocess.run(
                    ["task", "rc.confirmation=no", f"project:{name}", "status:active", "export"],
                    capture_output=True, text=True, timeout=10, env=env)
                pending_raw = json.loads(rp.stdout) if rp.stdout.strip() else []
                active_raw  = json.loads(ra.stdout) if ra.stdout.strip() else []
                all_tasks = pending_raw + active_raw
                active = sorted(
                    [t for t in active_raw],
                    key=lambda t: t.get("urgency") or 0, reverse=True)
                pending = sorted(
                    [t for t in pending_raw if t.get("projectrole") != "master"],
                    key=lambda t: t.get("urgency") or 0, reverse=True)
                master = next((t for t in all_tasks if t.get("projectrole") == "master"), None)

                def slim(t: dict) -> dict:
                    return {
                        "id": t.get("id"), "uuid": t.get("uuid"),
                        "description": t.get("description", ""),
                        "status": t.get("status", ""),
                        "urgency": round(t.get("urgency") or 0, 1),
                        "due": t.get("due", ""),
                        "tags": t.get("tags", []),
                        "projectrole": t.get("projectrole", ""),
                    }

                rc = subprocess.run(
                    ["task", "rc.confirmation=no", f"project:{name}", "status:completed", "count"],
                    capture_output=True, text=True, timeout=5, env=env)
                done = int(rc.stdout.strip()) if rc.stdout.strip().isdigit() else 0

                # Done tasks list (limited to 15 most recent)
                rd = subprocess.run(
                    ["task", "rc.confirmation=no", f"project:{name}", "status:completed", "export"],
                    capture_output=True, text=True, timeout=10, env=env)
                done_raw = json.loads(rd.stdout) if rd.stdout.strip() else []
                done_raw.sort(key=lambda t: t.get("end", ""), reverse=True)

                # Compute task-based time from start/end timestamps
                import time as _time_now
                _now = _time_now.time()
                pending_time_sec = 0
                done_time_sec = 0
                for _t in active_raw:
                    _s = _t.get("start", "")
                    if _s:
                        try: pending_time_sec += int(_now - _parse_timew_ts(_s))
                        except Exception: pass
                for _t in done_raw:
                    _s, _e = _t.get("start", ""), _t.get("end", "")
                    if _s and _e:
                        try: done_time_sec += int(_parse_timew_ts(_e) - _parse_timew_ts(_s))
                        except Exception: pass

                tasks_out = {
                    "active": [slim(t) for t in active[:5]],
                    "pending": [slim(t) for t in pending[:10]],
                    "pending_total": len(pending),
                    "done": done,
                    "done_list": [slim(t) for t in done_raw[:15]],
                    "master": slim(master) if master else None,
                    "pending_time_sec": pending_time_sec,
                    "done_time_sec": done_time_sec,
                }
            except Exception:
                pass

            # Journal entries for this project
            journal_out: dict = {"entries": [], "total": 0}
            try:
                journal_file = paths.get("journal_file", "")
                if journal_file and os.path.isfile(journal_file):
                    scanner_path = os.path.normpath(
                        os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                     "..", "..", "lib", "journal_scanner.py"))
                    if os.path.isfile(scanner_path):
                        r = subprocess.run(
                            ["python3", scanner_path, "parse", journal_file, "--project", name],
                            capture_output=True, text=True, timeout=10)
                        d = json.loads(r.stdout) if r.stdout.strip() else {}
                        entries = d.get("entries", [])
                        journal_out = {
                            "entries": [
                                {
                                    "date": e["date"],
                                    "date_slug": e["date_slug"],
                                    "preview": e["body"][:120].replace("\n", " "),
                                    "tags": e.get("tags", []),
                                    "priority": e.get("priority", ""),
                                }
                                for e in entries[:15]
                            ],
                            "total": len(entries),
                        }
            except Exception:
                pass

            # Ledger transactions tagged with this project
            ledger_out: dict = {"transactions": [], "total": 0}
            try:
                ledger_file = paths.get("ledger_file", "")
                if ledger_file and os.path.isfile(ledger_file):
                    import re as _re_pd
                    with open(ledger_file) as fh:
                        raw_lines = fh.readlines()
                    txns: list[dict] = []
                    i = 0
                    while i < len(raw_lines):
                        raw = raw_lines[i].rstrip()
                        tm = _re_pd.match(r'^(\d{4}-\d{2}-\d{2})\s+(.*)', raw)
                        if tm:
                            date, desc = tm.group(1), tm.group(2).strip()
                            j = i + 1
                            proj_match = False
                            postings: list[dict] = []
                            while j < len(raw_lines):
                                pline = raw_lines[j].rstrip()
                                if not pline.strip() or (pline.strip() and not pline[0].isspace()):
                                    break
                                cm = _re_pd.match(r'\s+;\s*(.*)', pline)
                                if cm and f"project:{name}" in cm.group(1):
                                    proj_match = True
                                pm = _re_pd.match(r'\s+(\S[^;]*?)\s{2,}(\S+.*)', pline)
                                if pm and not pline.strip().startswith(';'):
                                    postings.append({"account": pm.group(1).strip(),
                                                     "amount": pm.group(2).strip()})
                                j += 1
                            if proj_match:
                                txns.append({"date": date, "description": desc,
                                             "postings": postings})
                            i = j
                        else:
                            i += 1
                    ledger_out = {"transactions": txns[:15], "total": len(txns)}
            except Exception:
                pass

            # TimeWarrior intervals tagged with this project
            timew_out: dict = {"intervals": [], "total_seconds": 0}
            try:
                twdb = paths.get("timewarriordb", "")
                if twdb:
                    timew_env = {**os.environ, "TIMEWARRIORDB": twdb}
                    tr = subprocess.run(
                        ["timew", "export", f"tag:{name}"],
                        capture_output=True, text=True, timeout=8, env=timew_env)
                    if tr.returncode == 0 and tr.stdout.strip():
                        intervals = json.loads(tr.stdout)
                        total_sec = 0
                        running_sec = 0
                        slim_ivs: list[dict] = []
                        import time as _time
                        now_ts = _time.time()
                        for iv in intervals:
                            if name not in (iv.get("tags") or []):
                                continue
                            start_str = iv.get("start", "")
                            end_str = iv.get("end", "")
                            if not start_str:
                                continue
                            try:
                                s = _parse_timew_ts(start_str)
                                if end_str:
                                    e2 = _parse_timew_ts(end_str)
                                    dur = int(e2 - s)
                                    total_sec += dur
                                    slim_ivs.append({
                                        "date": start_str[:8],
                                        "duration_sec": dur,
                                        "tags": iv.get("tags", []),
                                    })
                                else:
                                    running_sec = int(now_ts - s)
                                    total_sec += running_sec
                                    slim_ivs.append({
                                        "date": start_str[:8],
                                        "duration_sec": running_sec,
                                        "tags": iv.get("tags", []),
                                        "running": True,
                                    })
                            except Exception:
                                pass
                        slim_ivs.sort(key=lambda x: x["date"], reverse=True)
                        timew_out = {
                            "intervals": slim_ivs[:20],
                            "total_seconds": total_sec,
                            "running_seconds": running_sec,
                        }
            except Exception:
                pass

            self._send_json(200, {
                "ok": True, "name": name,
                "tasks": tasks_out,
                "journal": journal_out,
                "ledger": ledger_out,
                "timew": timew_out,
            })

        # -- GET /data/nav-config -------------------------------------------

        def _handle_data_nav_config(self) -> None:
            """Return nav order: default merged with active profile or global nav.yaml override."""
            default_order = [
                "projects", "groups", "questions", "next", "schedule",
                "sync", "warlock", "models", "network", "bookbuilder", "export"
            ]
            order = list(default_order)
            try:
                profile = state.get_active_profile()
                base = state.ww_base
                if profile and base:
                    nav_path = os.path.join(base, "profiles", profile, "nav.yaml")
                    if not os.path.isfile(nav_path):
                        # Fall back to global default in .claude/ww/nav.yaml
                        nav_path = os.path.join(base, ".claude", "ww", "nav.yaml")
                    if os.path.isfile(nav_path):
                        with open(nav_path) as fh:
                            lines = fh.readlines()
                        in_services = False
                        parsed: list = []
                        for line in lines:
                            stripped = line.rstrip()
                            if stripped.strip() == "services:":
                                in_services = True
                                continue
                            if in_services:
                                m = __import__("re").match(r"^\s+-\s+(\S+)", stripped)
                                if m:
                                    parsed.append(m.group(1))
                                elif stripped and not stripped[0].isspace():
                                    break
                        if parsed:
                            order = parsed
            except Exception:
                pass
            self._send_json(200, {"ok": True, "services": order})

        # -- GET /data/task-meta --------------------------------------------

        def _handle_data_tags(self) -> None:
            """Return all tags with task counts, task lists, priorities, and UDA presence per tag."""
            paths = state.get_profile_paths()
            if not paths:
                self._send_json(200, {"ok": False, "tags": []})
                return
            env = {**os.environ, "TASKRC": paths["taskrc"], "TASKDATA": paths["taskdata"]}
            try:
                # Discover UDA names from taskrc
                uda_names = []
                try:
                    with open(paths["taskrc"]) as fh:
                        for line in fh:
                            m = _re.match(r'^uda\.([^.]+)\.type=', line.strip())
                            if m and m.group(1) not in ("priority",):
                                if m.group(1) not in uda_names:
                                    uda_names.append(m.group(1))
                except Exception:
                    pass
                # Get all tags
                rt = subprocess.run(["task", "_tags"], capture_output=True, text=True, timeout=5, env=env)
                raw_tags = [t.strip() for t in (rt.stdout or "").splitlines()
                            if t.strip() and not t.strip().startswith("next")]
                tags_out = []
                for tag in sorted(raw_tags):
                    try:
                        # Count pending tasks with this tag
                        rc = subprocess.run(
                            ["task", "rc.confirmation=no", f"+{tag}", "status:pending", "count"],
                            capture_output=True, text=True, timeout=5, env=env)
                        count = int(rc.stdout.strip()) if rc.stdout.strip().isdigit() else 0
                        # Export tasks with this tag
                        re_ = subprocess.run(
                            ["task", "rc.confirmation=no", f"+{tag}", "status:pending", "export"],
                            capture_output=True, text=True, timeout=8, env=env)
                        tasks = json.loads(re_.stdout) if re_.stdout.strip() else []
                        tasks.sort(key=lambda t: t.get("urgency") or 0, reverse=True)
                        # Collect priorities and UDAs present across tasks
                        priorities = sorted({t.get("priority","") for t in tasks if t.get("priority","")})
                        udas_present = sorted({u for u in uda_names
                                               for t in tasks if t.get(u) not in (None, "", [])})
                        slim_tasks = [{"id": t.get("id"), "uuid": t.get("uuid"),
                                       "description": t.get("description", ""),
                                       "project": t.get("project", ""),
                                       "priority": t.get("priority", ""),
                                       "urgency": round(t.get("urgency") or 0, 1),
                                       "modified": t.get("modified", ""),
                                       "entry": t.get("entry", ""),
                                       "udas": {u: t.get(u) for u in uda_names if t.get(u) not in (None,"",[])}
                                       } for t in tasks[:20]]
                        latest_mod = max((t.get("modified") or t.get("entry") or "" for t in tasks), default="")
                        tags_out.append({"tag": tag, "count": count, "tasks": slim_tasks,
                                         "latest_modified": latest_mod,
                                         "priorities": priorities,
                                         "udas": udas_present})
                    except Exception:
                        tags_out.append({"tag": tag, "count": 0, "tasks": [], "priorities": [], "udas": []})
                self._send_json(200, {"ok": True, "tags": tags_out, "uda_names": uda_names})
            except Exception as exc:
                self._send_json(200, {"ok": False, "error": str(exc), "tags": []})

        def _handle_data_task_meta(self) -> None:
            """Return task projects and tags from taskwarrior for use in dropdowns."""
            paths = state.get_profile_paths()
            if not paths:
                self._send_json(200, {"ok": False, "projects": [], "tags": []})
                return
            env = {**os.environ, "TASKRC": paths["taskrc"], "TASKDATA": paths["taskdata"]}
            projects, tags = [], []
            try:
                r = subprocess.run(["task", "_projects"], capture_output=True, text=True, timeout=5, env=env)
                projects = [p.strip() for p in (r.stdout or "").splitlines() if p.strip()]
            except Exception:
                pass
            try:
                r = subprocess.run(["task", "_tags"], capture_output=True, text=True, timeout=5, env=env)
                tags = [t.strip() for t in (r.stdout or "").splitlines()
                        if t.strip() and t.strip() == t.strip().lower()]
            except Exception:
                pass
            self._send_json(200, {"ok": True, "projects": sorted(projects), "tags": sorted(tags)})

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

        # -- GET /export/snapshot -------------------------------------------

        def _handle_export_snapshot(self) -> None:
            """Generate a self-contained static HTML snapshot of the active profile."""
            paths = state.get_profile_paths()
            profile = state.get_active_profile() or "unknown"
            exported_at = time.strftime("%Y-%m-%d %H:%M UTC", time.gmtime())

            tasks, journal_entries, balances = [], [], []

            if paths:
                env_t = {**os.environ, "TASKRC": paths["taskrc"], "TASKDATA": paths["taskdata"]}
                try:
                    r1 = subprocess.run(["task", "rc.confirmation=no", "status:pending", "export"],
                        capture_output=True, text=True, timeout=10, env=env_t)
                    r2 = subprocess.run(["task", "rc.confirmation=no", "status:active", "export"],
                        capture_output=True, text=True, timeout=10, env=env_t)
                    pending = json.loads(r1.stdout) if r1.stdout.strip() else []
                    active = json.loads(r2.stdout) if r2.stdout.strip() else []
                    tasks = active + [t for t in pending if t.get("uuid") not in {a["uuid"] for a in active}]
                    tasks.sort(key=lambda t: t.get("urgency", 0), reverse=True)
                except Exception:
                    pass
                try:
                    import re as _re
                    content_j = open(paths["journal_file"]).read()
                    parts = _re.split(r'\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2})\]', content_j)
                    for i in range(1, len(parts) - 1, 2):
                        body = parts[i + 1].strip()
                        if body:
                            journal_entries.append({"date": parts[i], "body": body})
                    journal_entries.reverse()
                    journal_entries = journal_entries[:30]
                except Exception:
                    pass
                try:
                    bal = subprocess.run(
                        ["hledger", "-f", paths["ledger_file"], "balance", "--flat", "--no-total"],
                        capture_output=True, text=True, timeout=10)
                    import re as _re2
                    if bal.returncode == 0:
                        for line in bal.stdout.splitlines():
                            m = _re2.match(r'\s+([-$£€\d,. ]+\S)\s{2,}(\S+.*)', line.rstrip())
                            if m:
                                balances.append({"amount": m.group(1).strip(), "account": m.group(2).strip()})
                except Exception:
                    pass

            def esc(s):
                return str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

            task_rows = ""
            for t in tasks:
                pri = t.get("priority", "")
                pri_cls = {"H": "pri-h", "M": "pri-m", "L": "pri-l"}.get(pri, "")
                tags = ", ".join(t.get("tags", []))
                due = (t.get("due", "") or "")[:10]
                task_rows += (
                    f'<tr><td>{esc(t.get("description",""))}</td>'
                    f'<td>{esc(t.get("project",""))}</td>'
                    f'<td>{esc(tags)}</td>'
                    f'<td class="{pri_cls}">{esc(pri)}</td>'
                    f'<td>{esc(due)}</td></tr>\n'
                )

            journal_html = ""
            for e in journal_entries:
                body_lines = esc(e["body"]).replace("\n", "<br>")
                journal_html += f'<div class="j-entry"><div class="j-date">{esc(e["date"])}</div><div class="j-body">{body_lines}</div></div>\n'

            bal_rows = "".join(
                f'<tr><td>{esc(b["account"])}</td><td class="bal-amt">{esc(b["amount"])}</td></tr>\n'
                for b in balances
            )

            html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>ww snapshot · {esc(profile)}</title>
<style>
  *, *::before, *::after {{ box-sizing: border-box; }}
  body {{ font-family: 'JetBrains Mono', 'Fira Mono', monospace; background: #0e0e0e; color: #d0d0d0; margin: 0; padding: 24px; font-size: 13px; line-height: 1.5; }}
  h1 {{ font-size: 16px; color: #fff; margin: 0 0 4px; }}
  .meta {{ color: #666; font-size: 11px; margin-bottom: 32px; }}
  h2 {{ font-size: 13px; color: #aaa; border-bottom: 1px solid #222; padding-bottom: 6px; margin: 28px 0 12px; text-transform: uppercase; letter-spacing: .08em; }}
  table {{ width: 100%; border-collapse: collapse; margin-bottom: 16px; }}
  th {{ text-align: left; font-size: 10px; color: #555; text-transform: uppercase; letter-spacing: .06em; padding: 4px 8px 4px 0; border-bottom: 1px solid #222; }}
  td {{ padding: 5px 8px 5px 0; border-bottom: 1px solid #1a1a1a; vertical-align: top; }}
  .pri-h {{ color: #e74c3c; font-weight: bold; }}
  .pri-m {{ color: #e67e22; }}
  .pri-l {{ color: #888; }}
  .j-entry {{ margin-bottom: 16px; padding-bottom: 16px; border-bottom: 1px solid #1a1a1a; }}
  .j-date {{ font-size: 10px; color: #555; margin-bottom: 4px; }}
  .j-body {{ color: #c8c8c8; }}
  .bal-amt {{ text-align: right; font-variant-numeric: tabular-nums; color: #7ec8a0; }}
  .empty {{ color: #444; font-style: italic; }}
</style>
</head>
<body>
<h1>workwarrior · {esc(profile)}</h1>
<div class="meta">exported {esc(exported_at)} · {len(tasks)} tasks · {len(journal_entries)} journal entries</div>

<h2>Tasks</h2>
{"<table><thead><tr><th>Description</th><th>Project</th><th>Tags</th><th>Pri</th><th>Due</th></tr></thead><tbody>" + task_rows + "</tbody></table>" if tasks else '<p class="empty">no pending tasks</p>'}

<h2>Journal</h2>
{journal_html if journal_html else '<p class="empty">no journal entries</p>'}

<h2>Ledger</h2>
{"<table><thead><tr><th>Account</th><th style='text-align:right'>Balance</th></tr></thead><tbody>" + bal_rows + "</tbody></table>" if balances else '<p class="empty">no ledger data</p>'}
</body>
</html>"""

            body = html.encode("utf-8")
            filename = f"ww-snapshot-{profile}-{time.strftime('%Y%m%d')}.html"
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Disposition", f'attachment; filename="{filename}"')
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        # -- GET /data/next -------------------------------------------------

        def _handle_data_next(self) -> None:
            """Return the highest-urgency pending task as the recommended next task.
            Accepts ?skip=id1,id2,... to exclude specific task IDs from consideration."""
            paths = state.get_profile_paths()
            if not paths:
                self._send_json(200, {"ok": False, "error": "no active profile", "task": None})
                return
            from urllib.parse import urlparse, parse_qs
            skip_raw = parse_qs(urlparse(self.path).query).get("skip", [""])[0]
            skip_ids = {int(x) for x in skip_raw.split(",") if x.strip().isdigit()}
            env = {**os.environ, "TASKRC": paths["taskrc"], "TASKDATA": paths["taskdata"]}
            try:
                r = subprocess.run(
                    ["task", "rc.confirmation=no", "status:pending", "export"],
                    capture_output=True, text=True, timeout=10, env=env,
                )
                tasks = json.loads(r.stdout) if r.stdout.strip() else []
                if skip_ids:
                    tasks = [t for t in tasks if t.get("id") not in skip_ids]
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
                    "list":     state._active_list,
                },
            })

        # -- POST /resource --------------------------------------------------

        def _handle_resource(self) -> None:
            """
            Switch the active named resource for the current profile session.
            Body: {"kind": "journals"|"ledgers"|"tasklists"|"timew"|"lists", "name": "<key>"}
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
            Body: {"kind": "journals"|"ledgers"|"tasklists"|"timew"|"lists", "name": "<key>"}

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

            valid_kinds = ("journals", "ledgers", "tasklists", "timew", "lists")
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
                elif kind == "lists":
                    self._create_list_resource(profile_base, name, _re)
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

        def _create_list_resource(self, profile_base, name, _re):
            """Register a new list.py list (basename = name, file profile/list/<name>)."""
            if name == "default":
                raise _ResourceBadRequest("use a name other than 'default' (default list already exists)")
            list_dir = os.path.join(profile_base, "list")
            os.makedirs(list_dir, exist_ok=True)
            config_path = os.path.join(profile_base, "lists.yaml")
            if not os.path.isfile(config_path):
                with open(config_path, "w") as fh:
                    fh.write("lists:\n  default: tasks\n")
                tasks_path = os.path.join(list_dir, "tasks")
                if not os.path.isfile(tasks_path):
                    open(tasks_path, "a").close()
            list_file = os.path.join(list_dir, name)
            if os.path.exists(list_file):
                raise _ResourceConflict(f"list file '{name}' already exists")
            open(list_file, "a").close()
            self._yaml_insert(config_path, "lists:", f"  {name}: {name}", name, _re)
            self._finish_create("lists", name, list_file)

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
              list_add            — add a line to the active simple list (list.py)
              list_finish         — mark done (-f prefix)
              list_edit           — edit item (-e prefix text)
              list_remove         — remove item (-r prefix)
              ledger_add          — append a transaction to the profile's ledger file (supports optional comment field)
              ledger_annotate     — append a standalone comment line (; [date] desc: note)
              timew_start         — start time tracking with optional tags
              timew_stop          — stop current time tracking
              timew_track         — record a past time interval with duration and tags
              community_add       — add active-profile task or journal snapshot to a global community
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
                TASK_MUTATING = {"done", "start", "stop", "add", "annotate", "task_modify", "bulk", "dep_add", "dep_remove", "task_delete"}
                TIME_MUTATING = {"timew_start", "timew_stop", "timew_track", "timew_delete"}
                JOURNAL_MUTATING = {"journal_add", "journal_delete", "journal_archive", "journal_restore"}
                LEDGER_MUTATING = {"ledger_delete"}
                LIST_MUTATING = {"list_add", "list_finish", "list_edit", "list_remove"}
                COMMUNITY_MUTATING = {
                    "community_add", "community_create", "community_archive",
                    "community_unarchive", "community_describe", "community_rename",
                    "community_modify_entry", "community_refresh_entry",
                    "community_move_entry", "community_remove_entry",
                    "community_comment_save", "community_comment_copy_back",
                }

                if action == "done":
                    tid = str(body.get("id", ""))
                    # Fetch task details before marking done so we can log completion
                    proj_for_log = ""
                    desc_for_log = ""
                    try:
                        pre_r = subprocess.run(
                            ["task", "rc.confirmation=no", tid, "export"],
                            capture_output=True, text=True, timeout=5, env=env)
                        pre_tasks = json.loads(pre_r.stdout) if pre_r.stdout.strip() else []
                        if pre_tasks:
                            proj_for_log = pre_tasks[0].get("project", "")
                            desc_for_log = pre_tasks[0].get("description", "")
                    except Exception:
                        pass
                    r = run_task(tid, "done")
                    # Log completion to taskwarrior for project audit trail
                    if proj_for_log and desc_for_log:
                        try:
                            subprocess.run(
                                ["task", "rc.confirmation=no", "log", f"completed: {desc_for_log}", f"project:{proj_for_log}"],
                                capture_output=True, text=True, timeout=8, env=env)
                        except Exception:
                            pass
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
                    if args_obj.get("scheduled"):
                        cmd_parts.append(f"scheduled:{args_obj['scheduled']}")
                    if args_obj.get("wait"):
                        cmd_parts.append(f"wait:{args_obj['wait']}")
                    for tag in args_obj.get("tags", []):
                        cmd_parts.append(f"+{tag}")
                    r = run_task(*cmd_parts)
                    tasks = fetch_tasks()
                    import re as _re_ta
                    new_uuid = None
                    m_id = _re_ta.search(r'Created task (\d+)', r.stdout or '')
                    if m_id:
                        new_id_num = int(m_id.group(1))
                        for t in tasks:
                            if t.get('id') == new_id_num:
                                new_uuid = t.get('uuid')
                                break
                    self._send_json(200, {"ok": r.returncode == 0, "output": r.stdout or r.stderr, "tasks": tasks, "new_uuid": new_uuid})

                elif action == "annotate":
                    tid = str(body.get("id", ""))
                    note = body.get("args", {}).get("note", "")
                    r = run_task(tid, "annotate", note)
                    tasks = fetch_tasks()
                    self._send_json(200, {"ok": r.returncode == 0, "output": r.stdout or r.stderr, "tasks": tasks})

                elif action == "journal_add":
                    args_j = body.get("args", {})
                    entry_text = args_j.get("entry", "").strip()
                    if not entry_text:
                        self._send_json(400, {"ok": False, "error": "entry required"})
                        return
                    # Optional metadata markers (@project, @tags, @priority) appended after text
                    meta_parts = []
                    jrnl_project = (args_j.get("project") or "").strip()
                    jrnl_tags = (args_j.get("tags") or "").strip()
                    jrnl_priority = (args_j.get("priority") or "").strip()
                    if jrnl_project:
                        meta_parts.append(f"@project:{jrnl_project}")
                    if jrnl_tags:
                        meta_parts.append(f"@tags:{jrnl_tags}")
                    if jrnl_priority:
                        meta_parts.append(f"@priority:{jrnl_priority}")
                    full_text = entry_text + (" " + " ".join(meta_parts) if meta_parts else "")
                    # Optional journal override — write to a specific named journal
                    journal_name = args_j.get("journal", "")
                    target_file = paths["journal_file"]
                    if journal_name:
                        resources = state.get_profile_resources()
                        journals = resources.get("journals", {}) if resources else {}
                        if journal_name in journals:
                            target_file = journals[journal_name]
                    import time as time_mod
                    timestamp = time_mod.strftime("%Y-%m-%d %H:%M")
                    line = f"\n[{timestamp}] {full_text}\n"
                    with open(target_file, "a") as fh:
                        fh.write(line)
                    self._send_json(200, {"ok": True, "output": "entry added", "date": timestamp})

                elif action == "journal_annotate":
                    args_a = body.get("args", {})
                    date_slug = (args_a.get("date_slug") or "").strip()
                    ann_text = (args_a.get("text") or "").strip()
                    if not date_slug or not ann_text:
                        self._send_json(400, {"ok": False, "error": "date_slug and text required"})
                        return
                    journal_name = args_a.get("journal", "")
                    target_file = paths["journal_file"]
                    if journal_name:
                        resources = state.get_profile_resources()
                        journals = resources.get("journals", {}) if resources else {}
                        if journal_name in journals:
                            target_file = journals[journal_name]
                    scanner = _load_journal_scanner()
                    if scanner is None:
                        self._send_json(500, {"ok": False, "error": "journal_scanner unavailable"})
                        return
                    out = scanner.annotate_entry(target_file, date_slug, ann_text)
                    self._send_json(200, out)

                elif action == "journal_rejournal":
                    args_r = body.get("args", {})
                    source_slug = (args_r.get("source_slug") or "").strip()
                    entry_text = (args_r.get("text") or "").strip()
                    if not source_slug or not entry_text:
                        self._send_json(400, {"ok": False, "error": "source_slug and text required"})
                        return
                    journal_name = args_r.get("journal", "")
                    target_file = paths["journal_file"]
                    if journal_name:
                        resources = state.get_profile_resources()
                        jmap = resources.get("journals", {}) if resources else {}
                        if journal_name in jmap:
                            target_file = jmap[journal_name]
                    import time as time_mod
                    ts = time_mod.strftime("%Y-%m-%d %H:%M")
                    new_slug = ts.replace(' ', '_').replace(':', '-')
                    carry = (args_r.get("carry_marker") or "").strip()
                    body_lines = [f"rejournal-of:{source_slug}"]
                    if carry:
                        body_lines.append(carry)
                    body_lines.append(entry_text)
                    full_body = "\n".join(body_lines)
                    with open(target_file, "a") as fh:
                        fh.write(f"\n[{ts}] {full_body}\n")
                    # Annotate source entry with forward pointer
                    scanner_r = _load_journal_scanner()
                    if scanner_r:
                        scanner_r.annotate_entry(paths["journal_file"], source_slug,
                                                  f"rejournaled → {new_slug}")
                    self._send_json(200, {"ok": True, "new_slug": new_slug})

                elif action == "list_add":
                    args_o = body.get("args") or {}
                    item_text = str(args_o.get("text", "")).strip()
                    if not item_text or "\n" in item_text:
                        self._send_json(400, {"ok": False, "error": "text required (single line)"})
                        return
                    list_dir = paths.get("list_dir", "")
                    list_bn = paths.get("list_basename", "tasks")
                    if not list_dir:
                        self._send_json(400, {"ok": False, "error": "list_dir missing"})
                        return
                    os.makedirs(list_dir, exist_ok=True)
                    r = _run_list_py(state.ww_base, list_dir, list_bn, [item_text])
                    self._send_json(200, {
                        "ok": r.returncode == 0,
                        "output": (r.stdout or r.stderr or "").strip(),
                    })

                elif action == "list_finish":
                    prefix = str((body.get("args") or {}).get("prefix", "")).strip()
                    if not prefix:
                        self._send_json(400, {"ok": False, "error": "prefix required"})
                        return
                    list_dir = paths.get("list_dir", "")
                    list_bn = paths.get("list_basename", "tasks")
                    r = _run_list_py(state.ww_base, list_dir, list_bn, ["-f", prefix])
                    self._send_json(200, {
                        "ok": r.returncode == 0,
                        "output": (r.stdout or r.stderr or "").strip(),
                    })

                elif action == "list_edit":
                    args_o = body.get("args") or {}
                    prefix = str(args_o.get("prefix", "")).strip()
                    new_text = str(args_o.get("text", "")).strip()
                    if not prefix or not new_text:
                        self._send_json(400, {"ok": False, "error": "prefix and text required"})
                        return
                    list_dir = paths.get("list_dir", "")
                    list_bn = paths.get("list_basename", "tasks")
                    r = _run_list_py(state.ww_base, list_dir, list_bn, ["-e", prefix, new_text])
                    self._send_json(200, {
                        "ok": r.returncode == 0,
                        "output": (r.stdout or r.stderr or "").strip(),
                    })

                elif action == "list_remove":
                    prefix = str((body.get("args") or {}).get("prefix", "")).strip()
                    if not prefix:
                        self._send_json(400, {"ok": False, "error": "prefix required"})
                        return
                    list_dir = paths.get("list_dir", "")
                    list_bn = paths.get("list_basename", "tasks")
                    r = _run_list_py(state.ww_base, list_dir, list_bn, ["-r", prefix])
                    self._send_json(200, {
                        "ok": r.returncode == 0,
                        "output": (r.stdout or r.stderr or "").strip(),
                    })

                elif action == "ledger_add":
                    args_obj = body.get("args", {})
                    date = args_obj.get("date", time.strftime("%Y-%m-%d"))
                    desc = args_obj.get("description", "")
                    account = args_obj.get("account", "expenses:misc")
                    amount = args_obj.get("amount", "0")
                    comment = args_obj.get("comment", "").strip()
                    if not desc:
                        self._send_json(400, {"ok": False, "error": "description required"})
                        return
                    comment_line = f"\n    ; {comment}" if comment else ""
                    entry = f"\n{date} {desc}{comment_line}\n    {account}  {amount}\n    assets:checking\n"
                    with open(paths["ledger_file"], "a") as fh:
                        fh.write(entry)
                    self._send_json(200, {"ok": True, "output": "transaction added"})

                elif action == "ledger_annotate":
                    args_obj = body.get("args", {})
                    date = args_obj.get("date", time.strftime("%Y-%m-%d"))
                    desc = args_obj.get("description", "").strip()
                    note = args_obj.get("note", "").strip()
                    if not note:
                        self._send_json(400, {"ok": False, "error": "note required"})
                        return
                    line = f"; [{date}] {desc}: {note}\n" if desc else f"; [{date}] {note}\n"
                    with open(paths["ledger_file"], "a") as fh:
                        fh.write(line)
                    self._send_json(200, {"ok": True, "output": "annotation added"})

                elif action == "ledger_tag":
                    import re as _re_lt
                    args_obj = body.get("args", {})
                    date = args_obj.get("date", "").strip()
                    desc = args_obj.get("description", "").strip()
                    project = args_obj.get("project", "").strip()
                    priority = args_obj.get("priority", "").strip().upper()
                    task_uuid_arg = args_obj.get("task_uuid", "").strip()
                    raw_tags = args_obj.get("tags", [])
                    tags = [t.lstrip('#').strip() for t in raw_tags if isinstance(t, str) and t.strip()]
                    if not date or not desc:
                        self._send_json(400, {"ok": False, "error": "date and description required"})
                        return
                    if not project and not tags and not priority and not task_uuid_arg:
                        self._send_json(400, {"ok": False, "error": "at least one of project/tags/priority/task_uuid required"})
                        return
                    ledger_file = paths["ledger_file"]
                    try:
                        with open(ledger_file, "r") as fh:
                            lines = fh.readlines()
                        tx_start = None
                        for i, ln in enumerate(lines):
                            stripped = ln.strip()
                            if stripped.startswith(date) and desc.lower() in stripped.lower():
                                tx_start = i
                                break
                        if tx_start is None:
                            self._send_json(200, {"ok": False, "error": "transaction not found"})
                            return
                        # Find existing meta comment line inside the transaction block
                        existing_meta_idx = None
                        existing_proj = ''
                        existing_pri = ''
                        existing_task_uuid = ''
                        existing_tags: list = []
                        j = tx_start + 1
                        while j < len(lines):
                            ln = lines[j]
                            if not ln.strip() or (ln.strip() and not ln[0].isspace()):
                                break
                            cm = _re_lt.match(r'\s+;\s*(.*)', ln.rstrip())
                            if cm:
                                ct = cm.group(1)
                                if any(k in ct for k in ('project:', 'tag:', 'priority:', 'task:')):
                                    existing_meta_idx = j
                                    pm2 = _re_lt.search(r'\bproject:(\S+)', ct)
                                    if pm2:
                                        existing_proj = pm2.group(1)
                                    prm2 = _re_lt.search(r'\bpriority:([HMLhml])', ct)
                                    if prm2:
                                        existing_pri = prm2.group(1).upper()
                                    tum2 = _re_lt.search(r'\btask:([0-9a-f-]{36})', ct)
                                    if tum2:
                                        existing_task_uuid = tum2.group(1)
                                    for tg in _re_lt.finditer(r'\btag:(\S+)', ct):
                                        existing_tags.append(tg.group(1))
                                    break
                            j += 1
                        # Merge: new values override existing; tags are additive (unique)
                        final_proj = project if project else existing_proj
                        final_pri = priority if priority else existing_pri
                        final_task = task_uuid_arg if task_uuid_arg else existing_task_uuid
                        final_tags = list(dict.fromkeys(existing_tags + tags))
                        parts = []
                        if final_proj:
                            parts.append(f"project:{final_proj}")
                        if final_pri:
                            parts.append(f"priority:{final_pri}")
                        if final_task:
                            parts.append(f"task:{final_task}")
                        for tag in final_tags:
                            parts.append(f"tag:{tag}")
                        comment_line = "    ; " + "  ".join(parts) + "\n"
                        if existing_meta_idx is not None:
                            lines[existing_meta_idx] = comment_line
                        else:
                            lines.insert(tx_start + 1, comment_line)
                        with open(ledger_file, "w") as fh:
                            fh.writelines(lines)
                        self._send_json(200, {"ok": True, "output": "tags updated"})
                    except Exception as exc:
                        self._send_json(200, {"ok": False, "error": str(exc)})

                elif action == "ledger_untag":
                    import re as _re_lu
                    args_obj = body.get("args", {})
                    date = args_obj.get("date", "").strip()
                    desc = args_obj.get("description", "").strip()
                    remove_project = bool(args_obj.get("remove_project", False))
                    remove_priority = bool(args_obj.get("remove_priority", False))
                    remove_task = bool(args_obj.get("remove_task", False))
                    remove_tags = [t.lstrip('#').strip() for t in args_obj.get("remove_tags", []) if t.strip()]
                    if not date or not desc:
                        self._send_json(400, {"ok": False, "error": "date and description required"})
                        return
                    ledger_file = paths["ledger_file"]
                    try:
                        with open(ledger_file, "r") as fh:
                            lines = fh.readlines()
                        tx_start = None
                        for i, ln in enumerate(lines):
                            stripped = ln.strip()
                            if stripped.startswith(date) and desc.lower() in stripped.lower():
                                tx_start = i
                                break
                        if tx_start is None:
                            self._send_json(200, {"ok": False, "error": "transaction not found"})
                            return
                        meta_idx = None
                        meta_ct = ''
                        j = tx_start + 1
                        while j < len(lines):
                            ln = lines[j]
                            if not ln.strip() or (ln.strip() and not ln[0].isspace()):
                                break
                            cm = _re_lu.match(r'\s+;\s*(.*)', ln.rstrip())
                            if cm and any(k in cm.group(1) for k in ('project:', 'tag:', 'priority:', 'task:')):
                                meta_idx = j
                                meta_ct = cm.group(1)
                                break
                            j += 1
                        if meta_idx is None:
                            self._send_json(200, {"ok": True, "output": "nothing to remove"})
                            return
                        ct = meta_ct
                        if remove_project:
                            ct = _re_lu.sub(r'\bproject:\S+\s*', '', ct)
                        if remove_priority:
                            ct = _re_lu.sub(r'\bpriority:[HMLhml]\S*\s*', '', ct)
                        if remove_task:
                            ct = _re_lu.sub(r'\btask:[0-9a-f-]{36}\s*', '', ct)
                        for tag in remove_tags:
                            ct = _re_lu.sub(r'\btag:' + _re_lu.escape(tag) + r'\s*', '', ct)
                        ct = _re_lu.sub(r'\s{3,}', '  ', ct).strip()
                        if ct:
                            lines[meta_idx] = "    ; " + ct + "\n"
                        else:
                            del lines[meta_idx]
                        with open(ledger_file, "w") as fh:
                            fh.writelines(lines)
                        self._send_json(200, {"ok": True, "output": "tags removed"})
                    except Exception as exc:
                        self._send_json(200, {"ok": False, "error": str(exc)})

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
                    # Log the tracked session to taskwarrior if a project tag is found
                    if r.returncode == 0 and paths.get("taskrc"):
                        try:
                            exp_r = subprocess.run(
                                ["timew", "export", ":lastweek"],
                                capture_output=True, text=True, timeout=8, env=timew_env)
                            if exp_r.returncode == 0 and exp_r.stdout.strip():
                                intervals = json.loads(exp_r.stdout)
                                # Find most recently completed interval (has end, was just stopped)
                                closed = [iv for iv in intervals if iv.get("end")]
                                if closed:
                                    last = max(closed, key=lambda iv: iv.get("end", ""))
                                    tags = last.get("tags") or []
                                    proj_tags = [t for t in tags if not t.startswith("+")]
                                    project_tag = next((t for t in proj_tags if t), None)
                                    if project_tag:
                                        try:
                                            s = _parse_timew_ts(last["start"])
                                            e2 = _parse_timew_ts(last["end"])
                                            dur_min = int((e2 - s) / 60)
                                        except Exception:
                                            dur_min = 0
                                        if dur_min > 0:
                                            tag_str = " ".join(t for t in tags if t != project_tag)
                                            desc = f"timew: {dur_min}m{(' ' + tag_str) if tag_str else ''}"
                                            task_env = {**os.environ, "TASKRC": paths["taskrc"], "TASKDATA": paths["taskdata"]}
                                            subprocess.run(
                                                ["task", "rc.confirmation=no", "log", desc, f"project:{project_tag}"],
                                                capture_output=True, text=True, timeout=8, env=task_env)
                        except Exception:
                            pass
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

                elif action == "task_find_by_uuid":
                    uuid_arg = (body.get("args") or {}).get("uuid", "").strip()
                    if not uuid_arg:
                        self._send_json(400, {"ok": False, "error": "uuid required"})
                        return
                    resources = state.get_profile_resources()
                    tasklists = (resources or {}).get("tasklists", {})
                    timew_db = paths.get("timewarriordb", "")
                    for list_name, tl in tasklists.items():
                        trc = tl.get("taskrc", "")
                        tdata = tl.get("taskdata", "")
                        if not trc or not tdata:
                            continue
                        tenv = {**os.environ, "TASKRC": trc, "TASKDATA": tdata,
                                "TIMEWARRIORDB": timew_db}
                        r2 = subprocess.run(
                            ["task", "rc.confirmation=no", f"uuid:{uuid_arg}", "export"],
                            capture_output=True, text=True, timeout=10, env=tenv,
                        )
                        if r2.returncode == 0 and r2.stdout.strip():
                            try:
                                arr = json.loads(r2.stdout)
                                if arr:
                                    self._send_json(200, {"ok": True, "list_name": list_name, "task": arr[0]})
                                    return
                            except json.JSONDecodeError:
                                pass
                    self._send_json(200, {"ok": False, "error": "task not found in any list"})

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

                elif action == "project_create_master":
                    args_obj = body.get("args", {})
                    pname = args_obj.get("name", "").strip()
                    pdesc = args_obj.get("description", "").strip() or f"project: {pname}"
                    if not pname:
                        self._send_json(400, {"ok": False, "error": "project name required"})
                        return
                    if not paths:
                        self._send_json(400, {"ok": False, "error": "no active profile"})
                        return
                    env_m = {**os.environ,
                             "TASKRC": paths["taskrc"],
                             "TASKDATA": paths["taskdata"]}
                    # Guard: only one master per project
                    try:
                        chk = subprocess.run(
                            ["task", "rc.confirmation=no", f"project:{pname}",
                             "projectrole:master", "status:pending", "count"],
                            capture_output=True, text=True, timeout=5, env=env_m)
                        if chk.stdout.strip().isdigit() and int(chk.stdout.strip()) > 0:
                            self._send_json(409, {"ok": False,
                                "error": f"master task for '{pname}' already exists"})
                            return
                    except Exception:
                        pass
                    try:
                        r = subprocess.run(
                            ["task", "rc.confirmation=no", "add",
                             pdesc, f"project:{pname}", "projectrole:master", "priority:H"],
                            capture_output=True, text=True, timeout=10, env=env_m)
                        if r.returncode != 0:
                            self._send_json(500, {"ok": False, "error": r.stderr.strip()})
                            return
                        # Fetch the new task's UUID
                        uuid_r = subprocess.run(
                            ["task", "rc.confirmation=no", f"project:{pname}",
                             "projectrole:master", "status:pending", "_uuid"],
                            capture_output=True, text=True, timeout=5, env=env_m)
                        new_uuid = uuid_r.stdout.strip().splitlines()[-1] if uuid_r.stdout.strip() else ""
                        self._send_json(201, {"ok": True, "uuid": new_uuid, "project": pname})
                    except Exception as exc:
                        self._send_json(500, {"ok": False, "error": str(exc)})

                elif action == "community_add":
                    mod = _load_community_store()
                    if mod is None:
                        self._send_json(500, {"ok": False, "error": "community_store unavailable"})
                        return
                    args_o = body.get("args") or {}
                    comm = (args_o.get("community") or "").strip()
                    kind = (args_o.get("kind") or "").strip().lower()
                    profile = state.get_active_profile() or ""
                    if not comm or not kind:
                        self._send_json(400, {"ok": False, "error": "community and kind required"})
                        return
                    if not re.match(r"^[a-zA-Z0-9_-]+$", comm):
                        self._send_json(400, {"ok": False, "error": "invalid community name"})
                        return
                    if not profile:
                        self._send_json(400, {"ok": False, "error": "no active profile"})
                        return
                    comm_tags = (args_o.get("community_tags") or "").strip() or None
                    comm_priority = (args_o.get("community_priority") or "").strip() or None
                    comm_project = (args_o.get("community_project") or "").strip() or None
                    if kind == "task":
                        tid = str(args_o.get("task_id", "")).strip()
                        if not tid:
                            self._send_json(400, {"ok": False, "error": "task_id required"})
                            return
                        r = subprocess.run(
                            ["task", "rc.confirmation=no", tid, "export"],
                            capture_output=True, text=True, timeout=15, env=env,
                        )
                        if r.returncode != 0 or not (r.stdout or "").strip():
                            self._send_json(
                                400,
                                {"ok": False, "error": "task not found", "detail": (r.stderr or r.stdout or "")[:300]},
                            )
                            return
                        try:
                            arr = json.loads(r.stdout)
                        except json.JSONDecodeError:
                            self._send_json(400, {"ok": False, "error": "invalid task export"})
                            return
                        if not arr:
                            self._send_json(400, {"ok": False, "error": "task export empty"})
                            return
                        task_obj = arr[0]
                        uuid = str(task_obj.get("uuid") or "")
                        if not uuid:
                            self._send_json(400, {"ok": False, "error": "task has no uuid"})
                            return
                        source_ref = f"{profile}.task.{uuid}"
                        out = mod.add_entry(
                            state.ww_base, comm, source_ref, task_obj,
                            community_tags=comm_tags,
                            community_priority=comm_priority,
                            community_project=comm_project,
                        )
                    elif kind == "journal":
                        date_hdr = (args_o.get("journal_date") or "").strip()
                        if not date_hdr:
                            self._send_json(400, {"ok": False, "error": "journal_date required"})
                            return
                        journal_notebook = (args_o.get("journal") or "").strip() or "default"
                        journal_file = paths["journal_file"]
                        if journal_notebook != "default":
                            resources = state.get_profile_resources()
                            journals = (resources or {}).get("journals", {})
                            if journal_notebook in journals:
                                journal_file = journals[journal_notebook]
                        if not journal_file or not os.path.isfile(journal_file):
                            self._send_json(400, {"ok": False, "error": "journal file not found"})
                            return
                        out = mod.add_journal_from_file(
                            state.ww_base, comm, profile, journal_file, date_hdr, journal_notebook,
                            community_tags=comm_tags,
                            community_priority=comm_priority,
                            community_project=comm_project,
                        )
                    elif kind == "ledger":
                        tx_date = (args_o.get("tx_date") or "").strip()
                        tx_desc = (args_o.get("tx_desc") or "").strip()
                        tx_amt  = (args_o.get("tx_amt") or "").strip()
                        tx_proj = (args_o.get("tx_project") or "").strip()
                        tx_tags = (args_o.get("tx_tags") or [])
                        tx_pri  = (args_o.get("tx_priority") or "").strip()
                        if not tx_date or not tx_desc:
                            self._send_json(400, {"ok": False, "error": "tx_date and tx_desc required"})
                            return
                        source_ref = f"{profile}.ledger.{tx_date}|{tx_desc}"
                        captured = {
                            "date": tx_date, "description": tx_desc, "amount": tx_amt,
                            "project": tx_proj, "tags": tx_tags, "priority": tx_pri,
                        }
                        out = mod.add_entry(
                            state.ww_base, comm, source_ref, captured,
                            community_tags=comm_tags,
                            community_priority=comm_priority,
                            community_project=comm_project,
                        )
                    elif kind == "list":
                        list_prefix = (args_o.get("list_prefix") or "").strip()
                        list_text   = (args_o.get("list_text") or "").strip()
                        list_note   = (args_o.get("list_note") or "").strip()
                        if not list_text:
                            self._send_json(400, {"ok": False, "error": "list_text required"})
                            return
                        source_ref = f"{profile}.list.{list_prefix}|{list_text}"
                        captured = {
                            "prefix": list_prefix, "text": list_text, "note": list_note,
                        }
                        out = mod.add_entry(
                            state.ww_base, comm, source_ref, captured,
                            community_tags=comm_tags,
                            community_priority=comm_priority,
                            community_project=comm_project,
                        )
                    else:
                        self._send_json(400, {"ok": False, "error": "kind must be task, journal, ledger, or list"})
                        return
                    self._send_json(200, out)
                    if out.get("ok"):
                        state.broadcast("data", json.dumps({"type": "community"}))

                elif action == "community_comment_save":
                    # Save a comment on a community entry without writing to the journal.
                    args_cs = body.get("args") or {}
                    cs_text = args_cs.get("entry", "").strip()
                    cs_id = str(args_cs.get("entry_id", "")).strip()
                    if not cs_text or not cs_id:
                        self._send_json(400, {"ok": False, "error": "entry and entry_id required"})
                        return
                    mod = _load_community_store()
                    if mod is None:
                        self._send_json(500, {"ok": False, "error": "community_store unavailable"})
                        return
                    out = mod.add_comment(state.ww_base, int(cs_id), cs_text)
                    self._send_json(200, out)
                    if out.get("ok"):
                        state.broadcast("data", json.dumps({"type": "community"}))

                elif action == "community_journal_entry":
                    # Write a journal entry from a community entry.
                    # Journal-sourced: handled client-side (journal_annotate). This action
                    # is only called for task-sourced entries now — it writes a structured
                    # journal summary extracting key task fields, adds a community-ref
                    # backlink, and annotates the task in taskwarrior with a back-reference.
                    args_o = body.get("args") or {}
                    entry_text = args_o.get("entry", "").strip()
                    entry_id_str = str(args_o.get("entry_id", "")).strip()
                    if not entry_text or not entry_id_str:
                        self._send_json(400, {"ok": False, "error": "entry and entry_id required"})
                        return
                    mod = _load_community_store()
                    if mod is None:
                        self._send_json(500, {"ok": False, "error": "community_store unavailable"})
                        return
                    entry_id_int = int(entry_id_str)
                    backlink_meta = mod.get_entry_meta(state.ww_base, entry_id_int)
                    source_ref = backlink_meta.get("source_ref", "")
                    cap = backlink_meta.get("captured_state", {})
                    import time as time_mod
                    timestamp = time_mod.strftime("%Y-%m-%d %H:%M")
                    new_slug = timestamp.replace(" ", "_").replace(":", "-")
                    desc_snippet = (cap.get("description") or cap.get("body") or "")[:60].replace("|", "/").replace("]", ")")
                    backlink = f" [community-ref:{entry_id_int}|{source_ref}|{desc_snippet}]" if source_ref else ""
                    if ".task." in source_ref:
                        # Structured task journal entry — single [community-task:...] marker
                        # encodes all fields so the browser can render a rich card.
                        task_uuid = source_ref.split(".task.", 1)[-1]
                        desc = cap.get("description", "").strip()
                        status = cap.get("status", "")
                        project = cap.get("project", "")
                        priority = cap.get("priority", "")
                        due = (cap.get("due") or "")[:10]
                        tags = cap.get("tags", [])
                        tags_str = ",".join(tags) if isinstance(tags, list) else str(tags or "")
                        meta_parts = []
                        if status:   meta_parts.append(f"status:{status}")
                        if priority: meta_parts.append(f"priority:{priority}")
                        if due:      meta_parts.append(f"due:{due}")
                        if project:  meta_parts.append(f"project:{project}")
                        if tags_str: meta_parts.append(f"tags:{tags_str}")
                        meta_str = " ".join(meta_parts)
                        # Strip field-delimiter chars from user-controlled fields
                        safe_desc = desc.replace("|", "/").replace("]", ")")[:80]
                        safe_note = entry_text.replace("|", "/").replace("]", ")")
                        marker = (f"[community-task:{entry_id_int}|{task_uuid}"
                                  f"|{safe_desc}|{meta_str}|{safe_note}]")
                        line = f"\n[{timestamp}] {marker}\n"
                        try:
                            with open(paths["journal_file"], "a") as fh:
                                fh.write(line)
                        except OSError:
                            pass
                        # Annotate the task in taskwarrior with a back-reference
                        try:
                            t_profile = source_ref.split(".task.", 1)[0]
                            t_base = os.path.join(state.ww_base, "profiles", t_profile)
                            t_taskrc = os.path.join(t_base, ".taskrc")
                            t_taskdata = os.path.join(t_base, ".task")
                            t_env = {**os.environ, "TASKRC": t_taskrc, "TASKDATA": t_taskdata}
                            subprocess.run(
                                ["task", "rc.confirmation=no", task_uuid, "annotate",
                                 f"journaled: {new_slug} [community-ref:{entry_id_int}]"],
                                capture_output=True, text=True, timeout=10, env=t_env,
                            )
                        except Exception:
                            pass
                        self._send_json(200, {"ok": True, "journal_written": True,
                                              "backlink": backlink.strip(), "slug": new_slug})
                    else:
                        # Fallback for unknown source kinds: plain journal entry
                        desc_snippet = (cap.get("description") or cap.get("body") or "")[:80]
                        line = f"\n[{timestamp}] {entry_text}{backlink}\n"
                        try:
                            with open(paths["journal_file"], "a") as fh:
                                fh.write(line)
                        except OSError:
                            pass
                        self._send_json(200, {"ok": True, "journal_written": True,
                                              "backlink": backlink.strip()})

                elif action == "community_create":
                    args_cc = body.get("args") or {}
                    name = (args_cc.get("name") or "").strip()
                    if not name or not re.match(r"^[a-zA-Z0-9_-]+$", name):
                        self._send_json(400, {"ok": False, "error": "valid community name required"})
                        return
                    mod = _load_community_store()
                    if mod is None:
                        self._send_json(500, {"ok": False, "error": "community_store unavailable"}); return
                    _res = mod.create_community(state.ww_base, name)
                    self._send_json(200, _res)
                    if _res.get("ok"):
                        state.broadcast("data", json.dumps({"type": "community"}))

                elif action == "community_archive":
                    args_ca = body.get("args") or {}
                    name = (args_ca.get("name") or "").strip()
                    if not name:
                        self._send_json(400, {"ok": False, "error": "name required"}); return
                    mod = _load_community_store()
                    if mod is None:
                        self._send_json(500, {"ok": False, "error": "community_store unavailable"}); return
                    _res = mod.archive_community(state.ww_base, name)
                    self._send_json(200, _res)
                    if _res.get("ok"):
                        state.broadcast("data", json.dumps({"type": "community"}))

                elif action == "community_unarchive":
                    args_cu = body.get("args") or {}
                    name = (args_cu.get("name") or "").strip()
                    if not name:
                        self._send_json(400, {"ok": False, "error": "name required"}); return
                    mod = _load_community_store()
                    if mod is None:
                        self._send_json(500, {"ok": False, "error": "community_store unavailable"}); return
                    _res = mod.unarchive_community(state.ww_base, name)
                    self._send_json(200, _res)
                    if _res.get("ok"):
                        state.broadcast("data", json.dumps({"type": "community"}))

                elif action == "community_describe":
                    args_cd = body.get("args") or {}
                    name = (args_cd.get("name") or "").strip()
                    desc = (args_cd.get("description") or "").strip()
                    if not name:
                        self._send_json(400, {"ok": False, "error": "name required"}); return
                    mod = _load_community_store()
                    if mod is None:
                        self._send_json(500, {"ok": False, "error": "community_store unavailable"}); return
                    _res = mod.set_community_description(state.ww_base, name, desc)
                    self._send_json(200, _res)
                    if _res.get("ok"):
                        state.broadcast("data", json.dumps({"type": "community"}))

                elif action == "community_rename":
                    args_cr = body.get("args") or {}
                    old_name = (args_cr.get("old_name") or "").strip()
                    new_name = (args_cr.get("new_name") or "").strip()
                    if not old_name or not new_name:
                        self._send_json(400, {"ok": False, "error": "old_name and new_name required"}); return
                    if not re.match(r"^[a-zA-Z0-9_-]+$", new_name):
                        self._send_json(400, {"ok": False, "error": "invalid new name"}); return
                    mod = _load_community_store()
                    if mod is None:
                        self._send_json(500, {"ok": False, "error": "community_store unavailable"}); return
                    _res = mod.rename_community(state.ww_base, old_name, new_name)
                    self._send_json(200, _res)
                    if _res.get("ok"):
                        state.broadcast("data", json.dumps({"type": "community"}))

                elif action == "community_modify_entry":
                    args_me = body.get("args") or {}
                    try:
                        eid = int(args_me.get("entry_id", 0))
                    except (TypeError, ValueError):
                        self._send_json(400, {"ok": False, "error": "entry_id required"}); return
                    mod = _load_community_store()
                    if mod is None:
                        self._send_json(500, {"ok": False, "error": "community_store unavailable"}); return
                    deriv = args_me.get("is_community_derivative")
                    _res = mod.modify_entry(
                        state.ww_base, eid,
                        community_tags=(args_me.get("community_tags") or None),
                        community_priority=(args_me.get("community_priority") or None),
                        community_project=(args_me.get("community_project") or None),
                        is_community_derivative=(bool(deriv) if deriv is not None else None),
                    )
                    self._send_json(200, _res)
                    if _res.get("ok"):
                        state.broadcast("data", json.dumps({"type": "community"}))

                elif action == "community_refresh_entry":
                    args_rf = body.get("args") or {}
                    comm_name = (args_rf.get("community") or "").strip()
                    try:
                        eid = int(args_rf.get("entry_id", 0))
                    except (TypeError, ValueError):
                        self._send_json(400, {"ok": False, "error": "entry_id required"}); return
                    if not comm_name:
                        self._send_json(400, {"ok": False, "error": "community required"}); return
                    mod = _load_community_store()
                    if mod is None:
                        self._send_json(500, {"ok": False, "error": "community_store unavailable"}); return
                    # Re-export the task to get fresh captured state
                    meta = mod.get_entry_meta(state.ww_base, eid)
                    source_ref = meta.get("source_ref", "")
                    if ".task." not in source_ref:
                        self._send_json(400, {"ok": False, "error": "refresh only applies to task entries"}); return
                    task_uuid = source_ref.split(".task.", 1)[-1]
                    try:
                        r = subprocess.run(
                            ["task", "rc.confirmation=no", task_uuid, "export"],
                            capture_output=True, text=True, timeout=15, env=env,
                        )
                        arr = json.loads(r.stdout) if r.stdout.strip() else []
                        if not arr:
                            self._send_json(400, {"ok": False, "error": "task not found"}); return
                        _res = mod.refresh_entry(state.ww_base, comm_name, eid, arr[0])
                        self._send_json(200, _res)
                        if _res.get("ok"):
                            state.broadcast("data", json.dumps({"type": "community"}))
                    except Exception as exc:
                        self._send_json(500, {"ok": False, "error": str(exc)})

                elif action == "community_move_entry":
                    args_mv = body.get("args") or {}
                    try:
                        eid = int(args_mv.get("entry_id", 0))
                    except (TypeError, ValueError):
                        self._send_json(400, {"ok": False, "error": "entry_id required"}); return
                    from_comm = (args_mv.get("from_community") or "").strip()
                    to_comm = (args_mv.get("to_community") or "").strip()
                    if not from_comm or not to_comm:
                        self._send_json(400, {"ok": False, "error": "from_community and to_community required"}); return
                    mod = _load_community_store()
                    if mod is None:
                        self._send_json(500, {"ok": False, "error": "community_store unavailable"}); return
                    _res = mod.move_entry(state.ww_base, eid, from_comm, to_comm)
                    self._send_json(200, _res)
                    if _res.get("ok"):
                        state.broadcast("data", json.dumps({"type": "community"}))

                elif action == "community_recent":
                    args_rec = body.get("args") or {}
                    n = int(args_rec.get("n", 10))
                    mod = _load_community_store()
                    if mod is None:
                        self._send_json(500, {"ok": False, "error": "community_store unavailable"}); return
                    self._send_json(200, mod.recent_entries(state.ww_base, n))

                elif action == "community_remove_entry":
                    args_rem = body.get("args") or {}
                    comm_name = (args_rem.get("community") or "").strip()
                    try:
                        eid = int(args_rem.get("entry_id", 0))
                    except (TypeError, ValueError):
                        self._send_json(400, {"ok": False, "error": "entry_id required"}); return
                    if not comm_name:
                        self._send_json(400, {"ok": False, "error": "community required"}); return
                    mod = _load_community_store()
                    if mod is None:
                        self._send_json(500, {"ok": False, "error": "community_store unavailable"}); return
                    _res = mod.remove_entry(state.ww_base, comm_name, eid)
                    self._send_json(200, _res)
                    if _res.get("ok"):
                        state.broadcast("data", json.dumps({"type": "community"}))

                elif action == "community_comment_copy_back":
                    args_cb = body.get("args") or {}
                    try:
                        comment_id = int(args_cb.get("comment_id", 0))
                        eid = int(args_cb.get("entry_id", 0))
                    except (TypeError, ValueError):
                        self._send_json(400, {"ok": False, "error": "comment_id and entry_id required"}); return
                    comment_body = (args_cb.get("body") or "").strip()
                    mod = _load_community_store()
                    if mod is None:
                        self._send_json(500, {"ok": False, "error": "community_store unavailable"}); return
                    meta = mod.get_entry_meta(state.ww_base, eid)
                    source_ref = meta.get("source_ref", "")
                    if ".task." not in source_ref:
                        self._send_json(400, {"ok": False, "error": "copy-back only applies to task entries"}); return
                    task_uuid = source_ref.split(".task.", 1)[-1]
                    src_profile = source_ref.split(".task.", 1)[0]
                    t_base = os.path.join(state.ww_base, "profiles", src_profile)
                    t_taskrc = os.path.join(t_base, ".taskrc")
                    t_taskdata = os.path.join(t_base, ".task")
                    if not os.path.isfile(t_taskrc):
                        self._send_json(400, {"ok": False, "error": f"profile '{src_profile}' taskrc not found — cannot copy back"}); return
                    try:
                        t_env = {**os.environ, "TASKRC": t_taskrc, "TASKDATA": t_taskdata}
                        subprocess.run(
                            ["task", "rc.confirmation=no", task_uuid, "annotate", f"community: {comment_body}"],
                            capture_output=True, text=True, timeout=10, env=t_env,
                        )
                        mod.mark_comment_copied(state.ww_base, comment_id)
                        self._send_json(200, {"ok": True, "comment_id": comment_id, "copied": True})
                        state.broadcast("data", json.dumps({"type": "community"}))
                    except Exception as exc:
                        self._send_json(500, {"ok": False, "error": str(exc)})

                elif action == "bulk":
                    ids = body.get("ids", [])
                    op = body.get("op", "")
                    args_obj = body.get("args", {})
                    if not ids or not op:
                        self._send_json(400, {"ok": False, "error": "ids and op required"})
                        return
                    results = []
                    for tid in ids:
                        tid = str(tid)
                        if op == "done":
                            r = run_task(tid, "done")
                        elif op == "delete":
                            r = run_task("rc.confirmation=no", tid, "delete")
                        elif op == "modify":
                            cmd_parts = [tid, "modify"]
                            for k, v in args_obj.items():
                                if k == "tags_add":
                                    for tag in (v if isinstance(v, list) else [v]):
                                        cmd_parts.append(f"+{tag}")
                                elif k == "tags_remove":
                                    for tag in (v if isinstance(v, list) else [v]):
                                        cmd_parts.append(f"-{tag}")
                                elif v == "":
                                    cmd_parts.append(f"{k}:")
                                else:
                                    cmd_parts.append(f"{k}:{v}")
                            r = run_task(*cmd_parts)
                        else:
                            self._send_json(400, {"ok": False, "error": f"unknown bulk op: {op}"})
                            return
                        results.append({"id": tid, "ok": r.returncode == 0})
                    tasks = fetch_tasks()
                    self._send_json(200, {"ok": True, "results": results, "tasks": tasks})

                elif action in ("dep_add", "dep_remove"):
                    tid = str(body.get("id", "")).strip()
                    dep_uuid = str(body.get("dep_uuid", "")).strip()
                    if not tid or not dep_uuid:
                        self._send_json(400, {"ok": False, "error": "id and dep_uuid required"})
                        return
                    op = "depends+" if action == "dep_add" else "depends-"
                    r = subprocess.run(
                        ["task", "rc.confirmation=no", tid, "modify", f"{op}:{dep_uuid}"],
                        capture_output=True, text=True, timeout=10, env=env,
                    )
                    self._send_json(200, {"ok": r.returncode == 0, "error": r.stderr.strip() or None})

                elif action == "task_delete":
                    tid = str(body.get("id", "")).strip()
                    if not tid:
                        self._send_json(400, {"ok": False, "error": "id required"})
                        return
                    r = subprocess.run(
                        ["task", "rc.confirmation=no", tid, "delete"],
                        capture_output=True, text=True, timeout=10, env=env,
                    )
                    tasks = fetch_tasks() if r.returncode == 0 else []
                    self._send_json(200, {"ok": r.returncode == 0, "error": (r.stderr or "").strip() or None, "tasks": tasks})

                elif action == "journal_delete":
                    args_o = body.get("args") or {}
                    date_slug = (args_o.get("date_slug") or "").strip()
                    if not date_slug:
                        self._send_json(400, {"ok": False, "error": "date_slug required"})
                        return
                    paths = state.get_profile_paths()
                    journal_file = paths.get("journal_file", "") if paths else ""
                    if not journal_file or not os.path.isfile(journal_file):
                        self._send_json(400, {"ok": False, "error": "journal file not found"})
                        return
                    import re as _jre
                    # Reconstruct the date header from slug: "YYYY-MM-DD_HH-MM" → "YYYY-MM-DD HH:MM"
                    slug_parts = date_slug.split('_', 1)
                    date_part = slug_parts[0]
                    time_part = slug_parts[1].replace('-', ':', 1) if len(slug_parts) > 1 else '00:00'
                    date_hdr = f"{date_part} {time_part}"
                    content = open(journal_file, encoding='utf-8').read()
                    # Remove the entry block: from [date_hdr] to the next [date header] or end of file
                    pattern = r'\[' + _jre.escape(date_hdr) + r'\].*?(?=\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}\]|\Z)'
                    new_content = _jre.sub(pattern, '', content, flags=_jre.DOTALL)
                    with open(journal_file, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    self._send_json(200, {"ok": True})

                elif action == "journal_archive":
                    args_o = body.get("args") or {}
                    date_slug = (args_o.get("date_slug") or "").strip()
                    if not date_slug:
                        self._send_json(400, {"ok": False, "error": "date_slug required"})
                        return
                    paths = state.get_profile_paths()
                    journal_file = paths.get("journal_file", "") if paths else ""
                    if not journal_file or not os.path.isfile(journal_file):
                        self._send_json(400, {"ok": False, "error": "journal file not found"})
                        return
                    import re as _jre2
                    slug_parts = date_slug.split('_', 1)
                    date_part = slug_parts[0]
                    time_part = slug_parts[1].replace('-', ':', 1) if len(slug_parts) > 1 else '00:00'
                    date_hdr = f"{date_part} {time_part}"
                    content = open(journal_file, encoding='utf-8').read()
                    def _add_archived_marker(m):
                        block = m.group(0)
                        if '@status:archived' in block:
                            return block
                        return block.rstrip() + ' @status:archived\n\n'
                    pattern2 = r'\[' + _jre2.escape(date_hdr) + r'\].*?(?=\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}\]|\Z)'
                    new_content = _jre2.sub(pattern2, _add_archived_marker, content, flags=_jre2.DOTALL)
                    with open(journal_file, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    self._send_json(200, {"ok": True})

                elif action == "journal_restore":
                    args_o = body.get("args") or {}
                    date_slug = (args_o.get("date_slug") or "").strip()
                    if not date_slug:
                        self._send_json(400, {"ok": False, "error": "date_slug required"})
                        return
                    paths = state.get_profile_paths()
                    journal_file = paths.get("journal_file", "") if paths else ""
                    if not journal_file or not os.path.isfile(journal_file):
                        self._send_json(400, {"ok": False, "error": "journal file not found"})
                        return
                    import re as _jre2
                    slug_parts = date_slug.split('_', 1)
                    date_part = slug_parts[0]
                    time_part = slug_parts[1].replace('-', ':', 1) if len(slug_parts) > 1 else '00:00'
                    date_hdr = f"{date_part} {time_part}"
                    content = open(journal_file, encoding='utf-8').read()
                    def _remove_archived_marker(m):
                        block = m.group(0)
                        cleaned = _jre2.sub(r'\s*@status:archived', '', block)
                        return cleaned
                    pattern2 = r'\[' + _jre2.escape(date_hdr) + r'\].*?(?=\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}\]|\Z)'
                    new_content = _jre2.sub(pattern2, _remove_archived_marker, content, flags=_jre2.DOTALL)
                    with open(journal_file, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    self._send_json(200, {"ok": True})

                elif action == "ledger_delete":
                    args_o = body.get("args") or {}
                    tx_date = (args_o.get("date") or "").strip()
                    tx_desc = (args_o.get("description") or "").strip()
                    if not tx_date or not tx_desc:
                        self._send_json(400, {"ok": False, "error": "date and description required"})
                        return
                    paths = state.get_profile_paths()
                    if not paths:
                        self._send_json(400, {"ok": False, "error": "no active profile"})
                        return
                    resources = state.get_profile_resources() or {}
                    active_ledger = (resources.get("active") or {}).get("ledger", "default")
                    ledger_files = resources.get("ledgers", {})
                    ledger_file = ledger_files.get(active_ledger, paths.get("ledger_file", ""))
                    if not ledger_file or not os.path.isfile(ledger_file):
                        self._send_json(400, {"ok": False, "error": "ledger file not found"})
                        return
                    lines = open(ledger_file, encoding='utf-8').readlines()
                    # Find the transaction block starting with tx_date + space + tx_desc
                    target_prefix = f"{tx_date} {tx_desc}"
                    new_lines = []
                    i = 0
                    while i < len(lines):
                        line = lines[i]
                        if line.strip() and line.startswith(target_prefix):
                            # Comment out this block until blank line or EOF
                            new_lines.append('; ' + line)
                            i += 1
                            while i < len(lines) and lines[i].strip():
                                new_lines.append('; ' + lines[i])
                                i += 1
                        else:
                            new_lines.append(line)
                            i += 1
                    with open(ledger_file, 'w', encoding='utf-8') as f:
                        f.writelines(new_lines)
                    self._send_json(200, {"ok": True})

                elif action == "timew_delete":
                    args_o = body.get("args") or {}
                    timew_id = str(args_o.get("timew_id", "")).strip()
                    if not timew_id:
                        self._send_json(400, {"ok": False, "error": "timew_id required"})
                        return
                    r = subprocess.run(
                        ["timew", "delete", f"@{timew_id}", ":yes"],
                        capture_output=True, text=True, timeout=10, env=env,
                        input="",
                    )
                    self._send_json(200, {"ok": r.returncode == 0, "error": (r.stderr or "").strip() or None})

                else:
                    self._send_json(400, {"ok": False, "error": f"unknown action: {action}"})
                    return
                # Broadcast mutation event to SSE clients for live refresh
                if action in TASK_MUTATING:
                    state.broadcast("data", json.dumps({"type": "tasks"}))
                elif action in TIME_MUTATING:
                    state.broadcast("data", json.dumps({"type": "time"}))
                elif action in JOURNAL_MUTATING:
                    state.broadcast("data", json.dumps({"type": "journal"}))
                elif action in LIST_MUTATING:
                    state.broadcast("data", json.dumps({"type": "lists"}))
                elif action in LEDGER_MUTATING:
                    state.broadcast("data", json.dumps({"type": "ledger"}))
                elif action in COMMUNITY_MUTATING:
                    state.broadcast("data", json.dumps({"type": "community"}))

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
            self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
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
