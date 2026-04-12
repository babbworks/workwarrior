# Workwarrior

A profile-based productivity system for the terminal. Integrates TaskWarrior, TimeWarrior, JRNL, and Hledger under a unified CLI with isolated profiles, a browser UI, natural language command translation, and a growing set of weapons and services.

```
ww profile create work
p-work
task add "Ship the feature" project:api priority:H due:friday
j "Kicked off API sprint — targeting Friday release"
timew start api sprint
l balance
ww browser
```

## What It Does

Each profile is a self-contained workspace with its own tasks, time tracking, journals, ledgers, and configuration. Switch profiles instantly. No data bleeds between contexts.

The system wraps five tools — TaskWarrior, TimeWarrior, JRNL, Hledger, and Bugwarrior — behind a single `ww` command with 20+ service domains, a locally-served browser UI, and an optional AI layer for natural language command input.

## Installation

Requires bash/zsh on macOS or Linux. Python 3 for the browser UI and heuristic compiler.

```bash
git clone <repo-url> ~/ww
cd ~/ww
./install.sh
source ~/.bashrc   # or source ~/.zshrc
```

The installer detects your platform, checks for dependencies, and offers to install missing tools (TaskWarrior, TimeWarrior, JRNL, Hledger) via brew/apt/dnf/pacman. Each tool gets a version card showing installed vs. required versions.

```bash
./install.sh                    # Interactive
./install.sh --non-interactive  # Automated
./install.sh --force            # Reinstall/upgrade
./uninstall.sh                  # Remove (keeps profiles)
./uninstall.sh --purge          # Remove everything
```

## Quick Start

```bash
# Create and activate a profile
ww profile create work
p-work

# Tasks
task add "Review PR" project:api priority:H due:tomorrow +review
task add "Write tests" project:api priority:M due:friday
task list

# Time tracking (auto-starts via hook when you start a task)
task 1 start
timew summary

# Journal
j "Sprint planning complete — 8 stories committed"

# Ledger
l balance
l register expenses

# Browser UI
ww browser
```

## Core Commands

### Profile Management
```bash
ww profile create <name>     # Create isolated profile
ww profile list              # List all profiles
ww profile info <name>       # Show profile details
ww profile delete <name>     # Delete with safety backup
ww profile backup <name>     # Archive profile
ww profile import <archive>  # Create from archive
ww profile restore <archive> # Replace existing from archive
ww profile uda list          # List all UDAs with source badges
ww profile uda add <name>    # Interactive UDA creation
ww profile urgency           # Tune urgency coefficients
ww profile density           # Due-date density scoring
```

### Tasks, Time, Journals, Ledgers
```bash
# Shell functions (available after profile activation)
task [args]                  # TaskWarrior with profile isolation
timew [args]                 # TimeWarrior with profile isolation
j [journal] "entry"          # Write to journal
l [args]                     # Hledger with profile ledger

# Via ww command
ww journal add/list/remove/rename
ww ledger add/list/remove/rename
```

### Services
```bash
ww service list              # Discover available services
ww service info <name>       # Service details
ww ctrl status               # AI mode, prompt, UI settings
ww ctrl ai-on / ai-off       # Toggle AI
ww model list                # LLM provider/model registry
ww model providers           # List configured providers
ww group list/create/show    # Profile groups
ww find <term>               # Cross-profile search
ww shortcut list             # Shortcut reference
ww extensions taskwarrior list  # TW extension registry
ww deps install              # Install/check dependencies
ww q / ww questions          # Template-based workflows
```

### Weapons
```bash
ww gun <args>                # Bulk task series generator (taskgun)
ww sword <task-id> <parts>   # Split task into sequential subtasks
ww next                      # CFS-inspired next-task recommendation
ww schedule                  # Auto-scheduler (taskcheck)
```

### Issue Sync
```bash
i pull                       # Pull GitHub issues via bugwarrior
i status                     # Sync state
ww issues sync               # Two-way GitHub sync
ww issues push/pull          # Directional sync
ww issues custom             # Configure GitHub/Jira/etc.
```

### Profile Removal
```bash
ww remove <profile>          # Remove specific profiles (prompted)
ww remove --keep <profile>   # Remove all EXCEPT listed
ww remove --archive-all      # Archive all without prompting
ww remove --delete-all       # Delete all without prompting
ww remove --dry-run          # Preview what would happen
ww remove --list             # Show removable profiles
```

## Browser UI

`ww browser` launches a locally-served web interface with a dark terminal aesthetic.

```bash
ww browser                   # Start and open browser
ww browser --port 9090       # Custom port
ww browser --no-open         # Start without opening browser
ww browser stop              # Stop the server
```

Features:
- 15+ panels: Tasks, Time, Journals, Ledgers, CMD, CTRL, Sync, Groups, Models, Questions, Profile, and more
- Task inline editor with full UDA support (180+ UDAs rendered)
- Unified CMD input with natural language translation
- Heuristic matching (627 compiled regex rules) before AI fallback
- Compound commands: "add task review code and start tracking time"
- Route indicator: ⚡ AI or ⚙ heuristic for every command
- AI mode toggle: off / local-only (ollama) / local+remote
- Real-time SSE updates on profile changes
- Resource management: create/switch named journals, ledgers, time tracks
- Hledger integration: balances, register, income statement, balance sheet

## Heuristic Engine

The CMD service matches natural language input against 627 compiled regex rules before falling back to AI (ollama). Rules cover all 19 command domains with 6 phrasing variations per command.

```bash
# These all work without AI:
"add a task to review the budget"           → task add review the budget
"create task deploy server due friday"      → task add deploy server due:friday
"start tracking time on code review"        → timew start code review
"stop tracking"                             → timew stop
"show my profiles"                          → profile list
"finish task 5 and stop tracking"           → task 5 done + timew stop

# Recompile rules after adding commands:
ww compile-heuristics
ww compile-heuristics --verbose    # Detailed per-rule report
ww compile-heuristics --digest     # Include CMD log analysis
```

## AI Integration

Optional. Works with ollama (local) or remote providers. Configured per-profile.

```bash
# Global config
config/ai.yaml               # mode: off | local-only | local+remote
config/models.yaml            # Provider/model registry

# Per-profile override
profiles/<name>/ai.yaml       # Overrides global mode and provider

# CLI controls
ww ctrl ai-on                 # Enable AI
ww ctrl ai-off                # Disable AI
ww ctrl ai-status             # Show current AI state
ww model add-provider ollama ollama http://localhost:11434
ww model set-default llama3.2
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
  sync-*.sh, github-*.sh      GitHub two-way sync engine
  field-mapper.sh              TW ↔ GitHub field mapping
  ...

services/                     Service scripts
  browser/                    Browser UI (Python3 HTTP + SSE + static)
  ctrl/                       AI mode, prompt, UI settings
  cmd/                        Unified command service + JSONL logging
  remove/                     Profile removal with archive/delete
  models/                     LLM provider/model registry
  questions/                  Template-based workflows
  custom/                     Interactive config wizards + GitHub sync
  profile/                    Profile lifecycle + UDA management
  groups/                     Profile group management
  extensions/                 TW extension registry
  find/                       Cross-profile search
  export/                     Data export (JSON, CSV, markdown)
  ...

scripts/
  compile-heuristics.py       Heuristic rule compiler (627 rules, 19 domains)

weapons/
  gun/                        taskgun — bulk task series generator
  sword/                      Task splitting into sequential subtasks

config/
  ai.yaml                    AI mode and access points
  models.yaml                LLM provider/model registry
  ctrl.yaml                  CTRL service settings
  groups.yaml                Profile group definitions
  shortcuts.yaml             Shortcut/alias definitions
  projects.yaml              Cross-cutting project definitions

profiles/                    User profiles (gitignored, created at runtime)
  <name>/
    .taskrc                  TaskWarrior config
    .task/                   Task database
    .timewarrior/            TimeWarrior database
    journals/                JRNL journal files
    ledgers/                 Hledger ledger files
    jrnl.yaml                Journal name → file mapping
    ledgers.yaml             Ledger name → file mapping
```

## Environment Variables

Set automatically on profile activation:

| Variable | Purpose |
|---|---|
| `WARRIOR_PROFILE` | Active profile name |
| `WORKWARRIOR_BASE` | Active profile directory |
| `TASKRC` | Path to profile `.taskrc` |
| `TASKDATA` | Path to profile `.task` |
| `TIMEWARRIORDB` | Path to profile `.timewarrior` |

## Documentation

- `docs/overviews/INDEX.md` — full technical overview with architecture, data flows, and per-component docs
- `docs/usage-examples.md` — practical workflows
- `docs/search-guides/` — tool-specific search guides (task, time, journal, ledger, list)
- `docs/INSTALL.md` — detailed installation guide
- `docs/service-development.md` — how to build and register services

## Testing

```bash
bats tests/                          # Run all BATS tests
bats tests/test-models-service.bats  # Run specific suite
python3 -m pytest services/browser/  # Browser/heuristic tests
```

## License

See LICENSE file.
