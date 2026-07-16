# Workwarrior

![CI](https://github.com/babbworks/workwarrior/actions/workflows/ci.yml/badge.svg)

Workwarrior wraps five open-source tools — TaskWarrior, TimeWarrior, JRNL, Hledger, and Bugwarrior — into a single profile-based productivity system. Each profile is an isolated workspace: its own tasks, time tracking, journals, double-entry ledgers, and configuration. Switch contexts instantly. Nothing bleeds between profiles.

The system runs from the terminal, from a locally-served browser UI, or both at once. A natural language command layer translates plain English into tool commands using 627 compiled heuristic rules before optionally falling back to a local LLM.

---

## The Problem

Productivity tools force you into one paradigm. Task managers don't track time. Time trackers don't do accounting. Journals live in a separate app. And none of them understand that you might have three completely different work contexts that should never touch each other. Power users who want the full stack end up wiring together five tools manually and re-doing it every time they switch machines or add a context.

## How it Works

`ww` is a bash dispatcher that routes all commands to service scripts. `p-work` activates a profile by setting environment variables that all five tools read — no symlinks, no config switching. A 627-rule heuristic engine translates natural language input into tool commands without requiring AI. The browser UI (`ww browser`) serves a Python 3 HTTP server with 15+ panels, real-time SSE updates, and a unified command input.

## Current Status

Active development. The core **capture → record → interpret** pipeline is complete:

- **Stream** — an append-only event log recording all actors' punches (B start/stop). Multi-actor, real-time via TimeWarrior hooks. Board, reconciliation, and ingest deduplication all operational.
- **Ledger sync** — derived journal regenerated from stream.log as a pure function. Conservation law (Σ=0) enforced per transaction. Never appends, always regenerates.
- **Attention queue** — weighted valuation of actor accounts. Same records + different profile weights = different priority ranking. The floor-manager view and the "which task next" view are the same query.
- **Accrual rules** — opt-in auto-postings (work creates obligation). Write-back refusal enforced to prevent the verified double-count hazard.

Profile system, browser UI, natural language engine, GitHub two-way sync, UDA management, fleet dependency checking, and CI all working. 155 of 165 task cards complete.

---

```
p-work
task add "Ship the API" project:backend priority:H due:friday +release
j "Sprint 12 kicked off — targeting Friday for the API release"
timew start backend sprint
l balance
ww ledger attention --top 5
ww stream board
ww browser
```

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
  actors.yaml          Profile-tier actor weights (attention coefficients)
```

Activating a profile sets environment variables that all tools read:

```bash
ww profile create work       # Create a new profile
p-work                       # Activate it — sets TASKRC, TASKDATA, TIMEWARRIORDB, etc.
task list                    # TaskWarrior sees only this profile's tasks
timew summary                # TimeWarrior sees only this profile's time
j "Meeting notes"            # Writes to this profile's journal
l balance                    # Shows this profile's ledger balances
```

Profiles support multiple named resources, backup/restore, import from archives, grouping for batch operations, and clean removal with `ww remove`.

---

## The Stream Engine

Stream is the system's clock — one append-only log per instance, shared by every profile. Actors punch in and out; the log records who did what, when, on which object.

```bash
ww stream punch start lathe-01          # Actor punches in on an object
ww stream punch stop lathe-01           # Actor punches out
ww stream board                         # Who/what is currently IN
ww stream board --format json           # Machine-readable
ww stream reconcile human:op-03 lathe-01 --reason "shift boundary"
ww stream ingest --source timew         # Backfill from TimeWarrior history
```

The TimeWarrior on-modify hook makes `timew start/stop` emit stream events in real-time. TimeWarrior becomes a card reader, not a store — delete `~/.timewarrior` and lose nothing.

---

## The Attention Queue

"Which 3 machines need attention now?" and "which task should I do next?" are the same query — a valuation report over a synthetic commodity.

```bash
ww ledger attention                     # Ranked by weighted hours
ww ledger attention --top 5             # Top 5
ww ledger attention --format json       # For the browser/app
ww ledger attention --profile safety    # Same records, different weights, different ranking
ww ledger explain                       # Show auto-expanded postings (read-only view)
```

Actor weights in `profiles/<name>/actors.yaml` are the coefficient table. A mode IS a price table: same records under different coefficients produce different priority orders.

---

## The Browser UI

`ww browser` launches a locally-served web interface — no cloud, no accounts, no external dependencies. Python 3 stdlib only.

- **Tasks** — full task list with inline editing, UDA display, start/stop/done, annotations
- **Time** — today's total, weekly breakdown, recent intervals, start/stop controls
- **Journals** — entry list with expand/collapse, multi-journal selector, cross-journal links
- **Ledgers** — account balances, transactions, income statement, balance sheet
- **Stream** — the board (who's punched in), reconciliation controls
- **CMD** — unified command input with natural language translation
- **Saves** — knowledge base with search and tagging
- **Warrior** — cross-profile community view and export
- **CTRL, Models, Groups, Sync, Questions, Profile** — and more

```bash
ww browser                   # Start on port 7777 and open browser
ww browser --port 9090       # Custom port
```

---

## Natural Language Commands

627 compiled heuristic regex rules — no network, no latency, no LLM needed. Optional AI fallback for unusual phrasings.

```
"add a task to review the budget"              → task add review the budget
"start tracking time on code review"           → timew start code review
"show my attention queue"                      → ww ledger attention
"who is punched in right now"                  → ww stream board
"finish task 5 and stop tracking"              → task 5 done + timew stop
```

---

## Weapons

| Weapon | What it does |
|--------|-------------|
| **Gun** | Bulk task series generator with deadline spacing |
| **Sword** | Splits a task into N sequential subtasks with dependency chains |
| **Next** | CFS-inspired scheduler — recommends the optimal next task |
| **Schedule** | Auto-scheduler that assigns time blocks |

---

## GitHub Integration

**Bugwarrior** (one-way pull) — pulls issues from GitHub, GitLab, Jira, and 20+ services.

**ww github-sync** (two-way) — links tasks to GitHub issues. Pushes changes, pulls changes, handles conflict resolution and label encoding for UDA values.

---

## Fleet Management

```bash
ww deps check                # Check this instance's toolchain
ww deps check --all          # Fleet view — all registered instances
ww deps install hledger      # Install the official static build
```

Instances register at `~/.config/ww/registry/`. The fleet view reports which instances are below floor, stale, or missing tools — with JSON output for dashboards.

---

## Installation

Requires bash or zsh on macOS or Linux. Python 3.9+ for the browser UI and stream engine.

```bash
git clone <repo-url> ~/ww
cd ~/ww
./install.sh
source ~/.bashrc
```

The installer copies `bin/`, `lib/`, `scripts/`, `services/`, `resources/`, `config/`, `functions/`, `tools/`, and `dev/` (the full development substrate).

```bash
ww deps install              # Install/check core toolchain
ww deps check                # Show dependency status
```

---

## Services

| Domain | What it does |
|--------|-------------|
| `ww stream` | Append-only event log, punch verbs, board, reconciliation, hooks |
| `ww ledger` | Named ledgers, sync-stream, attention queue, explain, auto-rules |
| `ww profile` | Create, list, delete, backup, import, restore, UDA management |
| `ww journal` | Named journals, add/list/remove |
| `ww warrior` | Cross-profile view, community export (md/html/json) |
| `ww saves` | Knowledge base builder — save URLs, notes, search |
| `ww deps` | Dependency management, fleet view |
| `ww browser` | Locally-served web UI |
| `ww find` | Cross-profile search |
| `ww issues` | GitHub two-way sync + bugwarrior pull |
| `ww model` | LLM provider/model registry |
| `ww ctrl` | AI mode, prompt settings |
| `ww group` | Profile groups for batch operations |
| `ww questions` | Template-based capture workflows |
| `ww export` | Profile data export (JSON, CSV, markdown) |
| `ww extensions` | TaskWarrior/TimeWarrior extension registry |
| `ww compile-heuristics` | Recompile NL→command rules |

---

## Project Structure

```
bin/ww                        CLI dispatcher — all commands route here
lib/                          Core bash libraries (25+ files)
services/                     Service scripts (20 categories)
config/                       Runtime config (units, actors, dependencies, extensions, ai, models)
resources/                    Templates (rules.journal, agent-templates/)
scripts/                      Standalone tools (popup, heuristic compiler)
weapons/                      Gun, Sword
tools/                        List service
functions/                    Task/journal/issue functions
profiles/                     User profiles (runtime, gitignored)
dev/                          Development substrate (tasks, tests, specs, docs, schemas)
  tasks/                      165 task cards + generated INDEX
  tests/                      70+ BATS test files
  specs/                      Design documents
  schemas/                    Data contracts (stream-event-v1, actors-v1, units-v1, punch-posting-v1)
  docs/                       Internal technical docs
```

---

## Testing

```bash
bats dev/tests/                          # Run all BATS test suites
bats dev/tests/test-smoke.bats           # Smoke tests
bats dev/tests/test-ledger-attention.bats  # Specific suite
bash dev/scripts/check-identity-leak.sh  # Verify no identity leaks
```

CI runs on every push: smoke tests, 13 targeted BATS suites, identity gate, and INDEX staleness check.

---

## Documentation

- `docs/overviews/INDEX.md` — full technical overview
- `docs/usage-examples.md` — practical workflows
- `docs/INSTALL.md` — installation policy and platform notes
- `dev/docs/ledger-systems-accounting.md` — the thesis: double-entry as general systems accounting
- `dev/TASKS.md` — canonical task board
- `dev/schemas/` — data contracts
