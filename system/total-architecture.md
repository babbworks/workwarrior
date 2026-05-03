# Workwarrior — Total Architecture

A complete map of every layer, component, and dependency in the system. Read alongside `system/ONBOARDING.md` and `lib/CLAUDE.md`.

---

## What Workwarrior Is

Workwarrior wraps five open-source tools — **TaskWarrior, TimeWarrior, JRNL, Hledger, and Bugwarrior** — into a single profile-based productivity system. A profile is an isolated workspace with its own task database, time tracking, journals, ledgers, and configuration. Switching profiles switches all five tools at once via environment variables. No symlinks, no config overwriting — just env vars.

The system has three runtime surfaces: a terminal CLI (`ww`), a locally-served browser UI (`ww browser`), and a natural language command layer (CMD service) that translates plain English into tool commands.

---

## Three Directories

| Path                                | Role                                                             | Git? |
| ----------------------------------- | ---------------------------------------------------------------- | ---- |
| `~/Documents/Vaults/babb/repos/ww/` | **Repo** — all development                                       | yes  |
| `~/ww-dev/`                         | **Dev instance** — live testing against `ww-development` profile | no   |
| `~/ww/`                             | **Production instance** — real profiles, real data               | no   |

`~/ww-dev/` and `~/ww/` are deployed copies of the repo's program files. They receive updates via `system/scripts/dev-sync.sh`. Neither is a git repo — they hold runtime state (profiles, tools, state files) that never commits.

**What syncs vs. what doesn't:**

| Synced to ww-dev / ww | Never synced |
|---|---|
| `bin/`, `lib/`, `services/`, `resources/`, `weapons/` | `profiles/` — live task/time/journal/ledger data |
| `config/shortcuts.yaml`, `config/extensions.*.yaml`, `config/profile-meta-template.yaml` | `tools/` — runtime-installed extensions (warlock, etc.) |
| | `config/groups.yaml`, `ai.yaml`, `ctrl.yaml`, `models.yaml`, `projects.yaml` — user-configured |
| | `config/cmd-heuristics*.yaml` — generated artifacts |
| | `system/`, `tests/`, `docs/`, `stories/` |

---

## Directory Map

```
ww/
├── bin/
│   └── ww                      Main CLI dispatcher (4,918 lines)
├── lib/                        Sourced bash libraries (24 files, ~8,300 lines)
├── services/                   Service registry (25+ categories)
├── profiles/                   User workspaces — GITIGNORED, never touch directly
├── functions/                  Shell helper functions sourced at shell init
├── config/                     Global YAML configuration
├── resources/                  Default templates for new profiles
├── weapons/                    Weapon extensions (gun, sword)
├── scripts/                    Build scripts (compile-heuristics.py, scan-tw-extensions.py)
├── tools/                      Runtime-installed extensions — not in repo
├── tests/                      41 BATS test files + integration runners
├── docs/                       User-facing documentation
└── system/                     Dev control plane — not shipped
```

---

## Layer 1 — Shell Environment (Profile Activation)

When a user runs `p-work` (or any `p-<profile>` alias), `lib/shell-integration.sh` sets these environment variables in the current shell session:

| Variable | Example Value | What Reads It |
|---|---|---|
| `WARRIOR_PROFILE` | `work` | ww, services, lib functions |
| `WORKWARRIOR_BASE` | `~/ww/profiles/work` | all lib functions, all services |
| `TASKRC` | `~/ww/profiles/work/.taskrc` | TaskWarrior |
| `TASKDATA` | `~/ww/profiles/work/.task` | TaskWarrior |
| `TIMEWARRIORDB` | `~/ww/profiles/work/.timewarrior` | TimeWarrior |
| `BUGWARRIORRC` | `~/ww/profiles/work/.config/bugwarrior/bugwarriorrc` | Bugwarrior |
| `WW_BASE` | `~/ww` | bin/ww, services |

All five underlying tools read their own env vars natively — no ww wrapper needed for direct tool use. `ww` reads `WORKWARRIOR_BASE` and `WARRIOR_PROFILE` to know which profile is active for any command.

**`lib/shell-integration.sh` is SERIALIZED** — one writer at a time. It cannot have `set -euo pipefail` (it is sourced into interactive shells) and must never call `exit`.

---

## Layer 2 — Main Dispatcher (`bin/ww`)

The single entry point for all `ww` commands. 4,918 lines. One `main()` function routes every command through a case statement to either an inline `cmd_*` function or a direct service script invocation.

```
ww <command> [args]
     │
     ▼
main() — parse global flags, dispatch
     │
     ├── cmd_profile()          Profile create/list/info/backup/delete
     ├── cmd_warrior()          Cross-profile aggregation
     ├── cmd_browser()          → services/browser/browser.sh
     ├── cmd_questions()        Templated question workflows
     ├── cmd_groups()           Group management
     ├── cmd_models()           LLM model registry
     ├── cmd_resource()         Named resource management (journals, ledgers, lists)
     ├── cmd_deps()             Dependency installer
     ├── cmd_timew_*()          TimeWarrior extension install/manage
     ├── bash services/network/network.sh
     ├── bash services/saves/saves.sh
     ├── bash services/custom/github-sync.sh
     └── [25+ service dispatches total]
```

**Global flags parsed at startup:**

| Flag | Variable | Effect |
|---|---|---|
| `--profile <name>` | `WW_FLAG_PROFILE` | Override active profile for this command |
| `--global` | `WW_FLAG_GLOBAL` | Operate across all profiles |
| `--json` | `WW_FLAG_JSON` | Machine-readable JSON output |
| `--compact` | `WW_FLAG_COMPACT` | Compact text output |
| `--verbose` | `WW_VERBOSE` | Verbose logging |
| `--help` / `-h` | `WW_FLAG_HELP` | Route to help |

**Library sourcing at startup:**

```bash
source "$WW_BASE/lib/core-utils.sh"      # Always — fallback logging if missing
source "$WW_BASE/lib/profile-manager.sh" # Always
# Other libs sourced on-demand by individual cmd_ functions or services
```

`bin/ww` is **SERIALIZED** — one writer at a time. All service routing passes through it; conflicts produce broken CLI commands.

---

## Layer 3 — Library Layer (`lib/`)

All files in `lib/` are **sourced, not executed**. Critical rules:
- No `set -euo pipefail` — propagates into callers' shell context
- No `exit` — use `return` with exit codes only
- No `cd` — use absolute paths always
- All functions in `snake_case`, all locals declared with `local`

### 3.1 Foundation Libraries (Standard — normal change process)

| File                        | Lines | Purpose                                                           | Key Functions                                                                                                                     |
| --------------------------- | ----- | ----------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `core-utils.sh`             | 383   | Logging, validation, profile checks, service discovery            | `log_info/warning/error/success`, `validate_profile_name`, `profile_exists`, `require_active_profile`, `discover_services`, `die` |
| `profile-manager.sh`        | 1,817 | Profile lifecycle: create dirs, .taskrc, hooks, journals, ledgers | `create_profile_directories`, `create_taskrc`, `install_timewarrior_hook`, `add_journal_to_profile`, `create_ledger_config`       |
| `logging.sh`                | 411   | GitHub sync operation and error log management                    | `init_logging`, `log_sync_operation`, `log_error`, `log_operation_start/end`, `rotate_logs`                                       |
| `taskwarrior-api.sh`        | —     | TaskWarrior wrapper functions                                     | `get_task`, `task_exists`, `update_task`, `find_by_issue`, `annotate_task`                                                        |
| `config-loader.sh`          | 268   | GitHub sync config loading and validation                         | `load_github_sync_config`, `validate_github_sync_config`, `is_tag_excluded`                                                       |
| `config-utils.sh`           | —     | General config utilities                                          | —                                                                                                                                 |
| `error-handler.sh`          | 350   | Interactive GitHub API error recovery                             | `parse_github_error`, `handle_title_error`, `handle_rate_limit_error`, `handle_permission_error`                                  |
| `shortcode-registry.sh`     | 331   | Shortcode lookup                                                  | —                                                                                                                                 |
| `export-utils.sh`           | 711   | Data export helpers                                               | —                                                                                                                                 |
| `delete-utils.sh`           | 437   | Profile/task deletion utilities                                   | —                                                                                                                                 |
| `profile-stats.sh`          | 505   | Profile statistics and reporting                                  | —                                                                                                                                 |
| `dependency-installer.sh`   | 1,047 | Tool dependency detection and install                             | `check_dependencies`, `install_tool`                                                                                              |
| `installer-utils.sh`        | —     | Install helper utilities                                          | —                                                                                                                                 |
| `bugwarrior-integration.sh` | —     | Bugwarrior config and UDA management                              | —                                                                                                                                 |
| `community-db.sh`           | —     | Community database operations                                     | —                                                                                                                                 |
| `journal-scanner.sh`        | —     | Journal entry scanning and parsing                                | —                                                                                                                                 |

### 3.2 Shell Integration (SERIALIZED)

| File | Lines | Purpose | Key Functions |
|---|---|---|---|
| `shell-integration.sh` | 1,217 | Shell alias injection, profile activation, bare commands | `create_profile_aliases`, `remove_profile_aliases`, `use_task_profile`, `get_ww_rc_files`, `ww_resolve_scope`, `ensure_global_workspace` |

This file is sourced into the user's interactive shell. It injects:
- `p-<profile>` activation aliases
- `<profile>` shorthand aliases
- `j-<journal>` journal aliases
- `l-<ledger>` ledger aliases
- Bare command wrappers: `task`, `timew`, `j`, `l`, `list`, `profile`, `profiles`, `journals`

### 3.3 GitHub Sync Engine (ALL HIGH FRAGILITY)

Nine interdependent files. Any change to a leaf propagates risk to all callers above it.

```
services/custom/github-sync.sh   (user-facing entry point)
  └── lib/sync-bidirectional.sh
        ├── lib/sync-pull.sh          (GitHub → TaskWarrior)
        │     ├── lib/github-api.sh
        │     ├── lib/field-mapper.sh
        │     ├── lib/annotation-sync.sh
        │     └── lib/github-sync-state.sh
        ├── lib/sync-push.sh          (TaskWarrior → GitHub)
        │     ├── lib/github-api.sh
        │     ├── lib/field-mapper.sh
        │     ├── lib/annotation-sync.sh
        │     └── lib/github-sync-state.sh
        └── lib/sync-detector.sh
              ├── lib/field-mapper.sh
              └── lib/github-sync-state.sh
```

| File | Risk | Purpose |
|---|---|---|
| `github-api.sh` | Network side effects, rate limiting | `gh` CLI wrapper: get/update issues, labels, comments |
| `github-sync-state.sh` | Data integrity — corruption breaks incremental sync | SQLite-backed sync state: `init_state_database`, `get/save_sync_state`, `is_task_synced` |
| `sync-detector.sh` | False negatives skip sync; false positives cause spurious writes | Change detection: `detect_task_changes`, `detect_github_changes`, `has_conflicts` |
| `field-mapper.sh` | Silent mapping errors cause data corruption | Data transformation TW ↔ GitHub: status, priority, tags, labels |
| `conflict-resolver.sh` | Wrong direction = permanent data loss | Last-write-wins: `compare_timestamps`, `resolve_conflict_last_write_wins` |
| `annotation-sync.sh` | Duplicate comment risk on repeated runs | TW annotations ↔ GitHub comments |
| `sync-pull.sh` | Can overwrite local task data | Pull GitHub issues into TaskWarrior |
| `sync-push.sh` | Can create/modify/close remote GitHub issues | Push local tasks to GitHub |
| `sync-bidirectional.sh` | Highest conflict window | Orchestrates pull + push: `sync_task_bidirectional`, `sync_all_tasks` |

**Before any change to these files, all four are required:** Orchestrator approval, extended risk brief (3+ paragraphs), integration tests against test profile, Verifier sign-off on the specific fragility concern.

---

## Layer 4 — Services (`services/`)

Services are executable scripts in `services/<category>/`. `ww` discovers them at runtime by scanning for executable files — no registration required. Profile-level services at `profiles/<name>/services/<category>/` shadow global services with the same filename.

### Service Categories

| Category | Script(s) | Purpose |
|---|---|---|
| `browser/` | `browser.sh`, `server.py` | Browser UI server (start/stop/status/export) |
| `cmd/` | — | Natural language command routing |
| `community/` | — | Community task database |
| `ctrl/` | — | System settings and AI access control |
| `custom/` | `github-sync.sh` + configure scripts | GitHub sync CLI and profile configure scripts |
| `diagnostic/` | — | Profile and configuration health checks |
| `export/` | — | Data export (CSV, JSON, PDF) |
| `extensions/` | — | TaskWarrior and TimeWarrior extension registry |
| `find/` | — | Cross-profile task search |
| `groups/` | — | Group management |
| `help/` | — | Help routing |
| `kompare/` | — | Cross-profile comparison |
| `models/` | — | LLM provider and model registry |
| `network/` | `network.sh` | Network and connectivity tools |
| `open/` | — | Open profile resources |
| `profile/` | `create-ww-profile.sh`, `manage-profiles.sh` | Profile creation and lifecycle |
| `projects/` | — | Project management |
| `questions/` | `q.sh` + templates + handlers | Templated question workflows |
| `remove/` | — | Profile and resource removal |
| `saves/` | `saves.sh` | BookBuilder / reading list |
| `scripts/` | — | Utility scripts (journals, ledgers, tasks, times, lists) |
| `servers/` | — | Server management |
| `unique/` | — | Unique task utilities |
| `verify/` | — | Verification tools |
| `warlock/` | `warlock.sh` | AI warlock integration |
| `warrior/` | `warrior.sh` | Cross-profile aggregation |
| `x-delete/` | — | Bulk deletion tools |
| `base/` | — | Base service scaffolding |
| `bookbuilder/` | — | NEVER COMMIT (gitignored) |

### Service Contract

Every service must:
- Respond to `--help` / `-h` with description and usage
- Use exit codes: 0 success, 1 user error, 2 system error
- Log via `lib/logging.sh`, never raw `echo`
- Never write directly to profile directories — call lib functions

### Service Template Tiers

**Tier 1 — Basic:** Standalone, logging only. No lib dependency.
**Tier 2 — With Templates:** Sources `config-loader.sh`, reads YAML templates from profile or global resources.
**Tier 3 — With Libs:** Sources `core-utils.sh`, `profile-manager.sh`, sync libs as needed.

---

## Layer 5 — Browser UI

The browser UI is a locally-served single-page application. No cloud, no external dependencies, no build step.

```
services/browser/
├── browser.sh      Bash entry point (start/stop/status/export)
├── server.py       Python 3 stdlib HTTP server (~5,200 lines)
└── static/
    ├── index.html  Single HTML shell (all panels rendered here)
    ├── style.css   All styles — CSS custom properties, no preprocessor
    └── app.js      All frontend logic — vanilla JS, no framework
```

### Server Architecture (`server.py`)

Python 3 stdlib only — `ThreadingHTTPServer` so SSE connections don't block POST requests.

**Endpoints:**

| Method | Path | Purpose |
|---|---|---|
| GET | `/health` | Readiness check — returns profile + version |
| GET | `/events` | Server-Sent Events stream (real-time updates) |
| POST | `/cmd` | Run any `ww` subcommand, return output |
| POST | `/profile` | Switch active profile |
| GET | `/data/tasks` | Pending task list for active profile |
| GET | `/data/time` | Time intervals and totals |
| GET | `/data/journal` | Recent journal entries |
| GET | `/data/lists` | Simple list items |
| GET | `/data/ledger` | Account balances and transactions |
| GET | `/data/tags` | Per-tag counts and task samples |
| GET | `/data/community/list` | Community list |
| GET | `/data/community/<name>` | Single community entries |
| POST | `/action` | Task mutations (done, start, stop, annotate, dep_add, etc.) |
| POST | `/resource/create` | Create named resource (journal/ledger/list) |

**Server-side components:**

| Class / Module | Purpose |
|---|---|
| `ServerState` | Holds active profile, port, SSE subscriber queue |
| `HeuristicEngine` | Loads and executes 627 compiled heuristic rules for NL→command translation |
| `_ping_thread()` | Sends SSE keepalive pings every 15 seconds |
| `_load_journal_scanner()` | Lazy-loads `lib/journal_scanner.py` |
| `_load_community_store()` | Lazy-loads `services/community/community_store.py` |
| `_resolve_ai_runtime()` | Reads `config/ai.yaml` + `config/models.yaml`, resolves active provider |

**State files (on disk, not in repo):**
```
$WW_BASE/.state/browser.pid   PID of running server process
$WW_BASE/.state/browser.port  Port the server is listening on
```

### Frontend Architecture

**Vanilla HTML + CSS + JS. No framework. No build step.**

- All panels rendered in `index.html` — single SPA shell
- State managed via module-level variables in `app.js`; persisted to `localStorage`
- SSE connection for real-time updates without polling
- CSS custom properties for all design tokens (dark theme only)

**Design token system (all in `style.css` `:root {}`):**

```css
--bg: #0d1117          /* page background */
--surface: #161b22     /* sidebar, panels */
--border: #21262d      /* all borders */
--text: #e6edf3        /* primary text */
--muted: #7d8590       /* secondary text */
--accent: #58a6ff      /* active, hover, links */
--success: #3fb950     /* green */
--warning: #d29922     /* amber */
--error: #f85149       /* red */
--clr-tasks: #3fb950   /* Tasks function color */
--clr-time: #79c0ff    /* Time function color */
--clr-journal: #d2883e /* Journal function color */
--clr-ledger: #e6edf3  /* Ledger function color */
```

**15+ UI panels:** Tasks, Times, Journals, Ledgers, Lists, Tags, CMD, CTRL, Models, Groups, Sync, Network, Questions, Saves, Projects, Community, Profile, Warlock, Export, Next, Schedule.

---

## Layer 6 — Natural Language / CMD Service

The CMD service accepts plain English and translates it into `ww` commands.

**Two-stage pipeline:**

```
User input
    │
    ▼
Stage 1: HeuristicEngine
    │    627 compiled regex rules (from config/cmd-heuristics.yaml)
    │    No network, no latency
    │    Returns: matched command + "heuristic" route indicator
    │
    ├── Match found → execute command
    │
    └── No match → Stage 2: AI Route
              │
              ├── Local LLM (ollama) if mode = local or local+remote
              │     Default model: llama3.2:latest via http://localhost:11434
              │
              └── Remote provider (OpenAI, etc.) if mode = local+remote
                    API key from env var per provider config
```

**Heuristics compilation:** `scripts/compile-heuristics.py` processes `config/cmd-heuristics-corpus.yaml` (human-readable source) into `config/cmd-heuristics.yaml` (compiled runtime format). The compiled file is gitignored — it is a generated artifact.

**AI configuration** lives in `config/ai.yaml`:
```yaml
mode: off             # off | local | local+remote
access_points:
  cmd_ai: true        # NL command translation
  sword_ai: false     # Sword weapon AI splitting
  questions_ai: false # Questions template AI suggestions
  saves_ai: true      # BookBuilder analysis
preferred_provider: ollama
```

**Model registry** in `config/models.yaml` — maps provider names and model IDs. Supports ollama (local) and OpenAI-compatible remote endpoints.

---

## Layer 7 — Profile Structure

Every profile is a directory under `$WW_BASE/profiles/<name>/`:

```
profiles/<name>/
├── .taskrc                   TaskWarrior config (UDAs, urgency coefficients, hooks path)
├── .task/                    TaskWarrior data
│   ├── taskchampion.sqlite3  Live task database — NEVER modify directly
│   └── hooks/                TaskWarrior hook scripts
│       └── on-modify.timewarrior  → triggers TimeWarrior on task start/stop
├── .timewarrior/             TimeWarrior database
│   ├── timewarrior.cfg
│   └── extensions/           TimeWarrior extension scripts
├── journals/                 JRNL journal files (one per named journal)
├── ledgers/                  Hledger ledger files (one per named ledger)
├── jrnl.yaml                 Journal name → file mapping
├── ledgers.yaml              Ledger name → file mapping
└── .config/
    └── bugwarrior/
        └── bugwarriorrc      Bugwarrior config (NEVER used for sync by agents)
```

**Multiple named resources per profile:** A single profile can have journals `strategy`, `engineering`, `personal` — each mapping to a distinct file. Same for ledgers. The infrastructure anticipates multiple task lists and TimeWarrior instances per profile in the future.

**Profile operations all go through `lib/profile-manager.sh`.** No agent or service writes directly to profile directories.

---

## Layer 8 — Configuration (`config/`)

Global configuration files. Most are user-managed; some are generated.

| File | Managed By | Purpose |
|---|---|---|
| `ai.yaml` | User / CTRL panel | AI mode, access points, preferred provider |
| `models.yaml` | User / Models service | LLM provider and model registry |
| `ctrl.yaml` | User / CTRL panel | UI display settings |
| `groups.yaml` | User | Profile groups for batch operations |
| `shortcuts.yaml` | Synced from repo | Command shortcuts |
| `projects.yaml` | User | Project definitions |
| `profile-meta-template.yaml` | Synced from repo | Template for new profile metadata |
| `extensions.taskwarrior.yaml` | Generated by scan script | TaskWarrior extension registry |
| `extensions.timewarrior.yaml` | Generated by scan script | TimeWarrior extension registry |
| `cmd-heuristics.yaml` | Generated by compile script | Compiled NL heuristic rules — NEVER COMMIT |
| `cmd-heuristics-corpus.yaml` | Developer | Source for heuristic rules — NEVER COMMIT |

---

## Layer 9 — Weapons (`weapons/`)

Weapon extensions add specialized task operations via the browser UI sidebar.

```
weapons/
├── sword/    Splits a task into sequential subtasks (with optional AI assistance)
└── gun/      Bulk task creation — series of related tasks from a template
```

Additional weapons (bat, fire, slingshot) are planned but not yet implemented. Placeholders exist in the browser sidebar.

---

## Layer 10 — Resources (`resources/`)

Default templates used when creating new profiles. Copied into profile directories at creation time, then owned by the profile.

```
resources/
├── config-files/     Default .taskrc, jrnl.yaml, ledgers.yaml templates
└── agent-templates/  Agent prompt templates for AI-assisted operations
```

---

## Layer 11 — External Tool Dependencies

Workwarrior requires these tools to be installed on the host system:

| Tool                      | Version | Role                                     |
| ------------------------- | ------- | ---------------------------------------- |
| TaskWarrior (`task`)      | ≥ 2.6   | Task database and CLI                    |
| TimeWarrior (`timew`)     | ≥ 1.4   | Time tracking                            |
| JRNL (`jrnl`)             | ≥ 2.8   | Journal entries                          |
| Hledger (`hledger`)       | ≥ 1.28  | Double-entry accounting                  |
| Bugwarrior (`bugwarrior`) | ≥ 1.8   | Issue tracker sync (optional)            |
| Python 3                  | ≥ 3.8   | Browser server, heuristics, community DB |
| `jq`                      | any     | JSON processing in services              |
| `gh` (GitHub CLI)         | any     | GitHub sync (optional)                   |
| SQLite3                   | any     | GitHub sync state database               |
| Ollama                    | any     | Local LLM (optional, for AI features)    |

`lib/dependency-installer.sh` handles detection and guided installation. `ww deps` runs it from the CLI.

---

## Data Flow: Command Execution

```
User types: ww task add "fix login bug" due:tomorrow

bin/ww main()
  → parse global flags
  → source lib/core-utils.sh (if not already)
  → dispatch to cmd_task() or bash services/...
      → require_active_profile()  [lib/core-utils.sh]
          → checks WORKWARRIOR_BASE is set
      → TASKRC=$TASKRC TASKDATA=$TASKDATA task add "fix login bug" due:tomorrow
          → TaskWarrior writes to profiles/<name>/.task/taskchampion.sqlite3
          → on-modify hook fires → TimeWarrior records context
```

## Data Flow: Browser Command via NL Input

```
User types: "add a task to review the budget"

app.js → POST /cmd {input: "add a task to review the budget"}

server.py HeuristicEngine.translate()
  → try 627 compiled regex rules
  → match: "add (a )?task to (.+)" → "task add review the budget"
  → return {command: "task add review the budget", route: "heuristic"}

server.py → subprocess: ww task add review the budget
  → TaskWarrior writes task
  → SSE broadcast → app.js refreshes Tasks panel
```

## Data Flow: Profile Activation

```
User types: p-work  (shell alias)

lib/shell-integration.sh use_task_profile("work")
  → validate profile exists at $WW_BASE/profiles/work
  → export WARRIOR_PROFILE=work
  → export WORKWARRIOR_BASE=~/ww/profiles/work
  → export TASKRC=~/ww/profiles/work/.taskrc
  → export TASKDATA=~/ww/profiles/work/.task
  → export TIMEWARRIORDB=~/ww/profiles/work/.timewarrior
  → export BUGWARRIORRC=~/ww/profiles/work/.config/bugwarrior/bugwarriorrc
  → update shell prompt indicator
```

---

## Fragility and Change Policy

### SERIALIZED — one writer at a time, never parallel

| File | Reason |
|---|---|
| `bin/ww` | All routing flows through here — merge conflicts are catastrophic |
| `lib/shell-integration.sh` | Broken shell integration breaks profile activation for all users |

### HIGH FRAGILITY — Orchestrator approval required before any change

All 9 files in the GitHub sync engine (see Layer 3.3 above). Any change requires: Orchestrator approval + extended risk brief + integration tests + dedicated Verifier sign-off.

### SENSITIVE — read-only for agents

All paths under `profiles/*/`. No agent may write directly. Use `lib/profile-manager.sh` functions.

### NEVER COMMIT

```
profiles/*/
.state/
.task/
__pycache__/
*.sqlite3
config/cmd-heuristics.yaml
config/cmd-heuristics-corpus.yaml
services/bookbuilder/
devsystem/
```

---

## Testing Architecture

```
tests/
├── CLAUDE.md                     Test strategy and known baseline failures
├── TESTING-QUICK-START.md        Quick reference for running tests
├── test-smoke.bats               Smoke tests — sourcing, logging, pipefail
├── test-foundation.sh            Component tests (State Manager, GitHub API, TW API)
├── test-github-sync.bats         GitHub sync unit tests (~50 cases)
├── test-sync-state.bats          Sync state database tests
├── test-profile-management-*.bats Profile lifecycle tests
├── test-profile-name-validation.bats Name validation edge cases
├── test-taskrc-*.bats            TaskRC creation and path tests
├── test-shell-functions.bats     Shell integration and alias tests
├── test-service-discovery.bats   Service discovery and override tests
├── test-browser*.bats            Browser service tests
├── test-community-*.bats         Community service tests
├── test-directory-structure.bats Profile directory layout tests
├── test-installation.bats        Install script tests
├── run-integration-tests.sh      Integration runner (requires gh auth + test profile)
└── test_helper/                  BATS helper utilities
```

**Known baseline failures (not regressions):** ~10 pre-existing failures in `test-profile-management-properties.bats` and `test-profile-name-validation.bats`. See `tests/CLAUDE.md` for the full list.

**Test requirements by change type:**

| Change | Required |
|---|---|
| Any `lib/` change | `bats tests/` — full suite |
| Any `services/` change | `bats tests/test-service-discovery.bats` + `bats tests/` |
| Profile behavior | `bash tests/test-foundation.sh` + `bats tests/` |
| `bin/ww` change | `bats tests/` + manual smoke: `ww help` |
| GitHub sync change | `./tests/run-integration-tests.sh` (requires `gh` auth + test profile) |

---

## Hard Quality Gates (merge blockers)

| Gate | Condition |
|---|---|
| **A** | No implementation starts without Orchestrator-authored acceptance criteria on the task card |
| **B** | No merge with failing required tests or unresolved high-severity Verifier findings |
| **C** | No task marked "complete" unless docs and CLI help strings match the implementation |
| **D** | No release claim without a fully signed release checklist |
| **E** | No untracked TODO or placeholder in production code — every deferred item has a TASKS.md card |
