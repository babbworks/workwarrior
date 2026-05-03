# Workwarrior

Workwarrior wraps five open-source tools — TaskWarrior, TimeWarrior, JRNL, Hledger, and Bugwarrior — into a single profile-based productivity system. Each profile is an isolated workspace: its own tasks, time tracking, journals, double-entry ledgers, and configuration. Switch contexts instantly. Nothing bleeds between profiles.

The system runs from the terminal, from a locally-served browser UI, or both at once. A natural language command layer translates plain English into tool commands using 627 compiled heuristic rules before optionally falling back to a local LLM.

```
p-work
task add "Ship the API" project:backend priority:H due:friday +release
j "Sprint 12 kicked off — targeting Friday for the API release"
timew start backend sprint
l balance
ww browser
```

---

## Why Workwarrior Exists

Most productivity tools force you into one paradigm. Task managers don't track time. Time trackers don't do accounting. Journals live in a separate app. Ledgers live in another. And none of them understand that you might have three completely different work contexts that should never touch each other.

Workwarrior doesn't replace these tools — it orchestrates them. TaskWarrior handles tasks. TimeWarrior tracks time. JRNL manages journals. Hledger does double-entry accounting. Each is best-in-class at what it does. Workwarrior adds the layer that makes them work together: profile isolation, unified commands, a browser UI, natural language input, and a growing set of services that connect everything.

The result is a system where `p-work` puts you in your work context with all five tools pointed at the right data, `p-personal` switches to your personal context, and `ww browser` gives you a visual dashboard over whichever profile is active — all without any of these tools knowing the others exist.

---

## Profiles

A profile is a directory containing everything for one work context:

```
profiles/<name>/
  .taskrc              TaskWarrior config and UDAs
  .task/               Task database + hooks
  .timewarrior/        TimeWarrior database
  journals/            JRNL journal files (multiple named journals supported)
  ledgers/             Hledger ledger files (multiple named ledgers supported)
  jrnl.yaml            Journal name → file mapping
  ledgers.yaml         Ledger name → file mapping
```

Activating a profile sets environment variables that all tools read. No symlinks, no config switching, no path hacking. Just env vars:

```bash
ww profile create work       # Create a new profile
p-work                       # Activate it — sets TASKRC, TASKDATA, TIMEWARRIORDB, etc.
task list                    # TaskWarrior sees only this profile's tasks
timew summary                # TimeWarrior sees only this profile's time
j "Meeting notes"            # Writes to this profile's journal
l balance                    # Shows this profile's ledger balances
```

Profiles support multiple named resources. A single profile can have journals called `strategy`, `engineering`, and `personal`, each mapping to a different file. Same for ledgers, and the infrastructure anticipates multiple task lists and time tracking instances per profile.

Profiles can be backed up, restored, imported from archives, grouped for batch operations, and removed cleanly with `ww remove` (which scrubs all references from config, state, aliases, and templates).

---

## The Browser UI

`ww browser` launches a locally-served web interface — no cloud, no accounts, no external dependencies. Python 3 stdlib only.

The UI has a dark terminal aesthetic with a collapsible sidebar, 15+ panels, and a unified command input that accepts both direct `ww` commands and natural language:

- **Tasks** — full task list with inline editing, UDA display, start/stop/done buttons, add task form, annotation management
- **Time** — today's total, weekly breakdown, recent intervals, start/stop controls
- **Journals** — entry list with expand/collapse, new entry form, multi-journal selector
- **Ledgers** — account balances, recent transactions, income statement, balance sheet, new transaction form
- **CMD** — unified command input with natural language translation and route indicator (⚡ AI or ⚙ heuristic)
- **CTRL** — AI mode toggle (off / local-only / local+remote), prompt settings, UI configuration
- **Models** — LLM provider and model registry
- **Groups, Sync, Questions, Profile** — and more

The server uses SSE for real-time updates and supports switching profiles and named resources from the browser.

```bash
ww browser                   # Start on port 7777 and open browser
ww browser --port 9090       # Custom port
ww browser stop              # Stop the server
```

---

## Natural Language Commands

The CMD service accepts plain English and translates it into tool commands. It tries 627 compiled heuristic regex rules first — no network, no latency, no LLM needed. If no rule matches, it optionally falls back to a local LLM (ollama) or a remote provider.

Inputs that work without AI:

```
"add a task to review the budget"              → task add review the budget
"create task deploy server due friday"         → task add deploy server due:friday
"start tracking time on code review"           → timew start code review
"stop tracking"                                → timew stop
"show my profiles"                             → profile list
"finish task 5 and stop tracking"              → task 5 done + timew stop
"add task fix login and annotate it with       → task add fix login
 check mobile layout"                            task annotate LAST check mobile layout
```

The heuristic engine covers all 19 command domains with 6 phrasing variations per command: passthrough, imperative, declarative, interrogative, shorthand, and verbose. Compound commands (joined by "and", "then", "also", "plus") are split and matched independently.

Rules are compiled by `ww compile-heuristics`, which scans all command sources, generates regex patterns, validates them against a synthetic corpus, resolves conflicts, fills coverage gaps, and writes the output. The engine is self-improving: every CMD submission is logged, and the `--digest` flag analyzes past AI translations to generate new rules.

```bash
ww compile-heuristics              # Recompile rules
ww compile-heuristics --verbose    # Show every rule with test results
ww compile-heuristics --digest     # Include CMD log analysis
```

---

## Weapons

Weapons are tools that manipulate profile data in special ways — creating, slicing, and packaging tasks.

| Weapon | What it does |
|--------|-------------|
| **Gun** | Bulk task series generator with deadline spacing. Wraps taskgun. |
| **Sword** | Splits a task into N sequential subtasks with dependency chains and due date offsets. Native to ww. |
| **Next** | CFS-inspired scheduler that recommends the optimal next task based on urgency, deadlines, and context. |
| **Schedule** | Auto-scheduler that assigns time blocks to tasks. Wraps taskcheck. |

```bash
ww sword 5 -p 3                    # Split task 5 into 3 sequential parts
ww sword 5 -p 4 --interval 2d     # 2-day intervals between parts
ww gun <args>                      # Generate bulk task series
ww next                            # What should I work on?
ww schedule                        # Auto-schedule tasks
```

---

## GitHub Integration

Two sync engines, complementary:

**Bugwarrior** (one-way pull) — pulls issues from GitHub, GitLab, Jira, Trello, and 20+ services into TaskWarrior. Configured per-profile.

**ww github-sync** (two-way) — links individual tasks to GitHub issues for bidirectional sync. Pushes task changes to GitHub, pulls GitHub changes to TaskWarrior. Handles field mapping, conflict resolution, annotation↔comment sync, and label encoding for UDA values.

```bash
i pull                             # Pull issues from configured services
i status                           # Show sync state
ww issues sync                     # Two-way sync all linked tasks
ww issues push                     # Push local changes to GitHub
ww issues enable <task> <issue#> <org/repo>  # Link a task to an issue
ww issues custom                   # Configure services interactively
```

---

## AI Integration

Optional. The system works fully without AI — the heuristic engine handles routine commands. AI adds flexibility for unusual phrasings and complex instructions.

```yaml
# config/ai.yaml
mode: local-only          # off | local-only | local+remote
preferred_provider: ollama
access_points:
  cmd_ai: true            # Enable AI in CMD service
```

Per-profile overrides via `profiles/<name>/ai.yaml`. Model fallback chains try multiple models before giving up. Controls available via CLI (`ww ctrl ai-on/off/status`) and browser CTRL panel.

```bash
ww model add-provider ollama ollama http://localhost:11434
ww model set-default llama3.2
ww ctrl ai-status                  # Show resolved AI state
```

---

## UDA System

TaskWarrior's User Defined Attributes are a first-class concept in Workwarrior. Profiles can carry 100+ UDAs covering project metadata, financial fields, compliance tracking, people, equipment, and more.

```bash
ww profile uda list                # All UDAs with source badges
ww profile uda add goals           # Interactive UDA creation
ww profile uda remove <name>       # Remove with safety warnings
ww profile uda group work          # Group UDAs for batch operations
ww profile uda perm goals nosync   # Set sync permissions per-UDA
```

UDAs are classified by source: `[github]` for bugwarrior-injected fields, `[extension]` for tool-added fields, `[custom]` for user-defined. The browser UI renders all UDAs in the task inline editor.

---

## Installation

Requires bash 3.2+ or zsh on macOS or Linux. Python 3 for the browser UI. Bash 5.x (via Homebrew on macOS) recommended.

```bash
git clone https://github.com/babbworks/ww ~/ww
cd ~/ww
./install.sh
source ~/.bashrc
```

The installer presents a version card for each tool showing installed, latest, and minimum required versions. On macOS it auto-installs via brew. On Linux it shows the right command for your distro.

```bash
ww deps install              # Install/check core toolchain
ww deps check                # Show dependency status
ww tui install               # Install taskwarrior-tui (optional)
ww mcp install               # Install MCP server for AI agents (optional)
```

---

## Services

Everything in Workwarrior is a service. The `ww` dispatcher routes commands to service scripts in `services/<category>/`.

| Domain | What it does |
|--------|-------------|
| `ww profile` | Create, list, info, delete, backup, import, restore, UDA management, urgency tuning, density scoring |
| `ww journal` | Add, list, remove, rename named journals |
| `ww ledger` | Add, list, remove, rename named ledgers |
| `ww group` | Profile groups for batch operations |
| `ww model` | LLM provider/model registry |
| `ww ctrl` | AI mode, prompt settings, UI configuration |
| `ww find` | Cross-profile search |
| `ww issues` | GitHub two-way sync + bugwarrior pull |
| `ww custom` | Interactive configuration wizards |
| `ww extensions` | TaskWarrior/TimeWarrior extension registry |
| `ww export` | Profile data export (JSON, CSV, markdown) |
| `ww questions` | Template-based capture workflows |
| `ww browser` | Locally-served web UI |
| `ww remove` | Profile removal with archive/delete/scrub |
| `ww shortcut` | Shortcut/alias reference |
| `ww deps` | Dependency management |
| `ww compile-heuristics` | Recompile NL→command rules |

Shell functions injected at init: `task`, `timew`, `j`, `l`, `i`, `q`, `list`, `search`, and `p-<name>` for each profile.

---

## Project Structure

```
bin/
  ww                          CLI dispatcher — all commands route here
  ww-init.sh                  Shell bootstrap (sourced at shell start)

lib/                          Core bash libraries
  core-utils.sh               Profile validation, path resolution
  profile-manager.sh           Profile lifecycle
  shell-integration.sh         Shell function injection, alias management
  sync-*.sh, github-*.sh      GitHub two-way sync engine (10 files)
  dependency-installer.sh      Platform-aware tool installer
  ...                          20+ library files

services/                     Service scripts
  browser/                    Browser UI (Python3 HTTP + SSE + static assets)
  ctrl/                       AI mode and settings
  cmd/                        Unified command service + JSONL logging
  remove/                     Profile removal
  models/                     LLM provider/model registry
  questions/                  Template-based workflows
  custom/                     Config wizards + GitHub sync
  profile/                    Profile lifecycle + UDA management
  groups/, find/, export/, extensions/, ...

weapons/
  gun/                        Bulk task series (taskgun)
  sword/                      Task splitting with dependency chains

scripts/
  compile-heuristics.py       Heuristic rule compiler

config/
  ai.yaml                    AI mode and access points
  models.yaml                LLM provider/model registry
  ctrl.yaml                  CTRL service settings
  groups.yaml                Profile group definitions
  shortcuts.yaml             Shortcut definitions

profiles/                    User profiles (created at runtime, gitignored)
```

---

## Documentation

- `docs/overviews/INDEX.md` — full technical overview with architecture, data flows, per-component docs
- `docs/usage-examples.md` — practical workflows and CLI patterns
- `docs/INSTALL.md` — detailed installation policy and platform notes
- `docs/search-guides/` — search guides per tool (task, time, journal, ledger, list)
- `docs/service-development.md` — how to build and register new services

---

## Testing

```bash
bats tests/                          # Run all BATS test suites
bats tests/test-models-service.bats  # Run a specific suite
python3 -m pytest services/browser/  # Browser and heuristic engine tests
```
