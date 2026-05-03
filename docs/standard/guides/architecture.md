# Architecture

## How It Fits Together

```
User types: p-work
  → shell-integration.sh sets TASKRC, TASKDATA, TIMEWARRIORDB, etc.
  → all tools now operate on the work profile's data

User types: task add "Ship API" due:friday
  → TaskWarrior writes to profiles/work/.task/
  → on-modify hook starts TimeWarrior tracking

User types: ww browser
  → Python3 HTTP server starts on localhost:7777
  → serves static UI + REST API + SSE events
  → reads profile data via same env vars

User types in browser CMD: "add task review code and start tracking"
  → HeuristicEngine matches against 627 rules
  → splits compound command on "and"
  → executes: task add review code + timew start review code
```

## Directory Structure

```
bin/
  ww                          CLI dispatcher (all commands route here)
  ww-init.sh                  Shell bootstrap (sourced at shell start)

lib/                          Core bash libraries (sourced, not executed)
  core-utils.sh               Profile validation, path resolution
  profile-manager.sh           Profile lifecycle
  shell-integration.sh         Shell function injection, alias management
  sync-*.sh, github-*.sh      GitHub two-way sync engine (10 files)
  dependency-installer.sh      Platform-aware tool installer
  ...                          20+ library files

services/                     25+ service categories
  browser/                    Browser UI (Python3 HTTP + SSE + static)
  ctrl/                       AI mode and settings
  cmd/                        Unified command service + JSONL logging
  remove/                     Profile removal
  models/                     LLM provider/model registry
  custom/                     Config wizards + GitHub sync
  profile/                    Profile lifecycle + UDA management
  ...

weapons/                      Task manipulation tools
  gun/                        Bulk task series (taskgun)
  sword/                      Task splitting with dependency chains

scripts/                      Build and utility scripts
  compile-heuristics.py       Heuristic rule compiler
  scan-taskwarrior-extensions.py  Extension registry scanner

config/                       Global YAML configuration
  ai.yaml                    AI mode and access points
  models.yaml                LLM provider/model registry
  ctrl.yaml                  CTRL service settings
  groups.yaml                Profile group definitions
  shortcuts.yaml             Shortcut definitions

profiles/                    User profiles (created at runtime)
```

## Environment Variables

Set automatically on profile activation:

| Variable           | Purpose                        |
| ------------------ | ------------------------------ |
| `WARRIOR_PROFILE`  | Active profile name            |
| `WORKWARRIOR_BASE` | Active profile directory       |
| `TASKRC`           | Path to profile `.taskrc`      |
| `TASKDATA`         | Path to profile `.task`        |
| `TIMEWARRIORDB`    | Path to profile `.timewarrior` |

Nothing in the system hardcodes paths. Everything resolves through these variables.

## Profile Isolation

Each profile is a self-contained directory. Tools are redirected via env vars, not symlinks or config switching. This means:
- Multiple profiles can exist simultaneously
- Switching is instant (just env var changes)
- No tool knows Workwarrior exists
- Backup is just tar the directory
- Restore is just untar and activate

## The Browser Server

Python 3 stdlib only. `ThreadingHTTPServer` handles SSE connections (which hold sockets open) without blocking concurrent POST requests. Static files served from disk on each request — changes visible on browser refresh without server restart.

Security boundary: `ALLOWED_SUBCOMMANDS` frozenset validates every POST /cmd request. No `sh -c`, no eval. First token must be a known ww subcommand.

## The Heuristic Engine

Loaded at server startup from `config/cmd-heuristics.yaml`. Each rule is a compiled regex with an action template and confidence score. The engine evaluates all rules against input, returns the highest-confidence match above threshold (0.8), or falls through to AI.

Compound commands are split on conjunctions ("and", "then", "also", "plus") and each segment is matched independently. If any segment fails to match, the entire input goes to AI.

## The Sync Engine

Ten files in `lib/` implement two-way GitHub sync. Classified as HIGH FRAGILITY — changes require extended risk briefs and integration tests. The engine handles:
- Change detection (which side modified since last sync)
- Field mapping (TaskWarrior ↔ GitHub formats)
- Conflict resolution (last-write-wins with configurable window)
- Annotation ↔ comment sync
- Label encoding for UDA values
- State persistence for incremental sync

## Testing

```bash
bats tests/                          # All BATS test suites
python3 -m pytest services/browser/  # Browser and heuristic tests
```

Tests run locally. No CI currently active.
