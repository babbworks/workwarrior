# Workwarrior Technical Overview

**Install path:** `/Users/mp/ww`
**Entry point:** `bin/ww` (2686 lines) — routes all `ww` commands to services and lib functions
**Shell bootstrap:** `bin/ww-init.sh` — sourced by `.bashrc`/`.zshrc` at shell start

---

## Architecture in One Paragraph

Workwarrior is a profile-based shell productivity system. A **profile** is an isolated directory (`profiles/<name>/`) containing its own TaskWarrior data, TimeWarrior database, journals, ledgers, and config. The `ww` CLI dispatcher (`bin/ww`) routes commands to **service scripts** (`services/<category>/`) and calls **lib functions** (`lib/*.sh`). Shell functions (`j`, `l`, `task`, `timew`, etc.) are injected into the user's shell via `lib/shell-integration.sh` at init time. Profile activation sets env vars (`WARRIOR_PROFILE`, `WORKWARRIOR_BASE`, `TASKRC`, `TASKDATA`, `TIMEWARRIORDB`) that all tools and services read. A **browser UI** (`ww browser`) serves a locally-hosted web interface with 15+ panels for tasks, time, journals, ledgers, profiles, and a unified CMD input with AI translation (ollama) and heuristic matching (627 compiled regex rules). The **heuristic engine** matches natural language input against rules before falling back to AI, with compound command support for multi-step operations. Nothing in the system hardcodes paths — everything resolves through env vars.

---

## Directory Map

```
bin/ww                    Main CLI dispatcher — all ww commands route through here
bin/ww-init.sh            Shell bootstrap — sourced at shell start
bin/profile               Profile activation helper
bin/custom                Custom service launcher
bin/export                Export launcher
bin/x                     Delete launcher

lib/                      Core bash libraries (sourced, not executed)
  core-utils.sh           WW_BASE resolution, profile validation, last-profile state
  profile-manager.sh      Profile lifecycle: create, delete, backup, import, restore
  shell-integration.sh    Shell function injection, alias management, rc file writes
  logging.sh              log_info/log_success/log_warning/log_error/log_step
  github-api.sh           GitHub REST API via gh CLI (check_gh_cli, get/update/label)
  github-sync-state.sh    Sync state persistence (save/get/remove sync state JSON)
  sync-pull.sh            GitHub → TaskWarrior pull with orphan detection
  sync-push.sh            TaskWarrior → GitHub push
  sync-bidirectional.sh   Orchestrates pull+push with conflict window management
  sync-detector.sh        Change detection: detect_task_changes, detect_github_changes
  field-mapper.sh         Field mapping between TW and GitHub formats
  conflict-resolver.sh    Last-write-wins conflict resolution
  annotation-sync.sh      TW annotations ↔ GitHub comments sync
  sync-permissions.sh     Per-UDA sync permission tokens (nosync, private, noai, etc.)
  config-loader.sh        Profile config loading (jrnl.yaml, ledgers.yaml)
  config-utils.sh         YAML parsing utilities
  taskwarrior-api.sh      tw_get_task, tw_update_task, tw_get_field wrappers
  bugwarrior-integration.sh  Bugwarrior config and pull helpers
  dependency-installer.sh Per-tool interactive installer with version cards
  installer-utils.sh      Install path resolution, shell RC block management
  export-utils.sh         Profile data export (JSON, CSV, markdown)
  delete-utils.sh         Profile deletion with backup safety
  profile-stats.sh        Profile statistics and reporting
  shortcode-registry.sh   Shortcut/alias registry read/write
  error-handler.sh        Error handling utilities

services/                 Service scripts (executable, discovered at runtime)
  profile/                Profile lifecycle commands
    create-ww-profile.sh  Full profile creation (dirs, taskrc, hooks, aliases)
    manage-profiles.sh    list/info/delete/backup/import/restore
    profile-tool.sh       Profile info display
    urgency.sh            ww profile urgency — coefficient management
    subservices/
      profile-uda.sh      ww profile uda — full UDA management surface
      profile-density.sh  ww profile density — TWDensity integration
      uda-manager.sh      Interactive UDA CRUD (legacy, still active)
  custom/                 Interactive configuration wizards
    configure-journals.sh ww custom journals
    configure-ledgers.sh  ww custom ledgers
    configure-tasks.sh    ww custom tasks
    configure-times.sh    ww custom times
    configure-issues.sh   ww custom issues / ww issues custom
    github-sync.sh        ww issues push/pull/sync/enable/disable/status
  questions/              Prompt template system
    q.sh                  Main questions dispatcher
    handlers/             Per-service question handlers
    templates/            YAML question templates
  extensions/             TaskWarrior extension registry
    extensions.sh         ww extensions taskwarrior list/search/info
    taskwarrior.py        Extension data fetcher
  find/                   Cross-profile search
    find.sh               ww find dispatcher
    find.py               Python search implementation
  groups/                 Profile group management
    groups.sh             ww group list/show/create/add/remove/delete
  models/                 LLM model registry
    models.sh             ww model list/providers/show/add/set-default
  export/                 Data export
    export.sh             ww export (JSON, CSV, markdown)
  x-delete/               Destructive operations
    x.sh                  ww x — profile/data deletion with backup
  browser/                Local web server (ww browser)
    server.py             Python3 HTTP server — 15+ panels, SSE, CMD AI, heuristic engine
    static/app.js         Browser UI — sidebar, task editor, time/journal/ledger panels
    static/index.html     HTML shell — dark terminal aesthetic
    static/style.css      Styles — monospace, collapsible sidebar, inline editors
  cmd/                    Unified command service
    cmd.log               JSONL log of all CMD submissions (route, input, output)
  ctrl/                   Control panel service
    ctrl.sh               ww ctrl status/ai-mode/ai-cmd/prompt-ww/prompt-ai
  projects/               Cross-cutting project views
  servers/                Server management
  scripts/                Utility scripts (journals, ledgers, tasks, times)

weapons/                  Weapon extensions
  gun/                    taskgun passthrough — bulk task series generator
  sword/                  Task splitting into sequential subtasks with dependencies

scripts/                  Build and utility scripts
  compile-heuristics.py   Heuristic compilation — scans commands, generates 627 regex rules

functions/                Shell helper functions (sourced at init)
  journals/               Journal helper scripts
  ledgers/                Ledger helper scripts
  tasks/                  TaskWarrior helper scripts and extensions
  times/                  TimeWarrior helper scripts
  issues/                 Issue tracking helpers

tools/                    Standalone tools
  list/list.py            List management tool (ww list)

config/                   Global YAML configuration
  ai.yaml                 AI mode, access points, preferred provider
  cmd-heuristics.yaml     Compiled NL→command heuristic rules (627 rules)
  cmd-heuristics-corpus.yaml  Synthetic corpus for heuristic validation
  ctrl.yaml               CTRL service settings (UI, command line display)
  groups.yaml             Profile group definitions
  models.yaml             LLM provider/model registry
  shortcuts.yaml          Shortcut/alias definitions
  projects.yaml           Cross-cutting project definitions
  extensions.taskwarrior.yaml  TaskWarrior extension registry
  extensions.timewarrior.yaml  TimeWarrior extension registry
  profile-meta-template.yaml   Profile metadata template

resources/                Default templates for new profiles
  config-files/.taskrc    Default TaskWarrior config template
  config-files/bugwarriorrc.template  Bugwarrior config template

system/                   Dev control plane (not shipped)
  ONBOARDING.md           Agent entry point
  CLAUDE.md               Full project context for agents
  TASKS.md                Canonical task board
```

---

## Profile Anatomy

```
profiles/<name>/
  .taskrc                 TaskWarrior config (TASKRC env var)
  .task/                  TaskWarrior data (TASKDATA env var)
    taskchampion.sqlite3  Task database
    hooks/
      on-modify.timewarrior  TimeWarrior hook (auto-installed)
    github-sync/          GitHub sync state files
  .timewarrior/           TimeWarrior data (TIMEWARRIORDB env var)
    timewarrior.cfg
    data/
    extensions/           Per-profile timew extensions (auto-created)
  .config/
    bugwarrior/           Bugwarrior config (BUGWARRIORRC env var)
    taskcheck/            taskcheck config + toggle flag
  journals/               JRNL journal files
  ledgers/                Hledger ledger files
  list/                   List tool workspace
  jrnl.yaml               Journal name → file path mapping
  ledgers.yaml            Ledger name → file path mapping
```

---

## Command Surface

| Command | Routes to | Description |
|---|---|---|
| `ww profile` | `services/profile/` | Profile lifecycle |
| `ww journal` | `cmd_journal()` in bin/ww | Journal add/list/remove/rename |
| `ww ledger` | `cmd_ledger()` in bin/ww | Ledger add/list/remove/rename |
| `ww group` | `services/groups/groups.sh` | Profile group management |
| `ww model` | `services/models/models.sh` | LLM model registry |
| `ww service` | `cmd_service()` in bin/ww | Service discovery |
| `ww extensions` | `services/extensions/extensions.sh` | TW extension registry |
| `ww find` | `services/find/find.sh` | Cross-profile search |
| `ww custom` | `services/custom/configure-*.sh` | Interactive config wizards |
| `ww issues` | `services/custom/github-sync.sh` + bugwarrior | Issue sync (two engines) |
| `ww export` | `services/export/export.sh` | Data export |
| `ww shortcut` | `lib/shortcode-registry.sh` | Shortcut reference |
| `ww deps` | `lib/dependency-installer.sh` | Dependency management |
| `ww tui` | `taskwarrior-tui` binary | Full-screen TUI |
| `ww next` | `next` binary (scheduler) | CFS next-task recommendation |
| `ww gun` | `taskgun` binary | Bulk task series generator |
| `ww schedule` | `taskcheck` binary | Auto-scheduler with toggle |
| `ww mcp` | `taskwarrior-mcp` binary | MCP server for AI agents |
| `ww browser` | `services/browser/` | Local web server |
| `ww profile density` | `services/profile/subservices/profile-density.sh` | Due-date density scoring |
| `ww profile urgency` | `services/profile/urgency.sh` | Urgency coefficient tuning |
| `ww profile uda` | `services/profile/subservices/profile-uda.sh` | UDA management |
| `ww ctrl` | `services/ctrl/ctrl.sh` | AI mode, prompt, UI settings |
| `ww sword` | `cmd_sword()` in bin/ww | Task splitting into sequential subtasks |
| `ww q` / `ww questions` | `services/questions/q.sh` | Template-based question workflows |
| `ww compile-heuristics` | `scripts/compile-heuristics.py` | Compile NL→command heuristic rules |

---

## Shell Functions (injected at init)

| Function | Routes to | Description |
|---|---|---|
| `p-<name>` | `use_task_profile()` | Activate a profile |
| `j [args]` | `jrnl` with profile config | Write to journal |
| `l [args]` | `hledger` with profile ledger | Access ledger |
| `task [args]` | `task` with profile TASKRC/TASKDATA | TaskWarrior |
| `timew [args]` | `timew` with profile TIMEWARRIORDB | TimeWarrior |
| `list [args]` | `tools/list/list.py` | List management |
| `i [args]` | `services/custom/github-sync.sh` + bugwarrior | Issue sync |
| `q [args]` | `services/questions/q.sh` | Questions service |
| `search [args]` | `ww find` | Cross-profile search |

---

## Data Flow: Profile Activation

```
p-work
  → use_task_profile("work")          [lib/shell-integration.sh]
  → export WARRIOR_PROFILE=work
  → export WORKWARRIOR_BASE=~/ww/profiles/work
  → export TASKRC=~/ww/profiles/work/.taskrc
  → export TASKDATA=~/ww/profiles/work/.task
  → export TIMEWARRIORDB=~/ww/profiles/work/.timewarrior
  → export BUGWARRIORRC=~/ww/profiles/work/.config/bugwarrior/bugwarriorrc
  → set_last_profile("work")          [lib/core-utils.sh]
  → all subsequent tool calls use profile-scoped data
```

## Data Flow: GitHub Sync (two-way)

```
ww issues sync
  → cmd_issues() → github-sync.sh sync
  → sync_preflight()                  [check gh CLI, jq, WORKWARRIOR_BASE]
  → sync_all_tasks()                  [lib/sync-bidirectional.sh]
    → for each synced task:
      → detect_task_changes()         [lib/sync-detector.sh]
      → detect_github_changes()       [lib/sync-detector.sh]
      → conflict resolution           [lib/conflict-resolver.sh]
      → sync_push_task() or sync_pull_issue()
        → github_update_issue()       [lib/github-api.sh]
        → tw_update_task()            [lib/taskwarrior-api.sh]
        → sync_annotations_to_comments() [lib/annotation-sync.sh]
        → save_sync_state()           [lib/github-sync-state.sh]
```

---

## Extension UDA Registry

Extensions that add UDAs are registered in `system/config/service-uda-registry.yaml`
under the `extensions:` section. They appear in `ww profile uda list` with
`[extension:<name>]` badges and are protected from accidental deletion.

| Extension | UDAs | Badge |
|---|---|---|
| TWDensity | `density`, `densitywindow` | `[extension:twdensity]` |
| taskcheck | `estimated`, `time_map` | `[extension:taskcheck]` |

---

## Fragility Map

| Classification | Files |
|---|---|
| HIGH FRAGILITY | `lib/github-api.sh`, `lib/github-sync-state.sh`, `lib/sync-pull.sh`, `lib/sync-push.sh`, `lib/sync-bidirectional.sh`, `lib/field-mapper.sh`, `lib/sync-detector.sh`, `lib/conflict-resolver.sh`, `lib/annotation-sync.sh`, `services/custom/github-sync.sh` |
| SERIALIZED | `bin/ww`, `lib/shell-integration.sh` |
| NEVER COMMIT | `profiles/*/.task/taskchampion.sqlite3`, `profiles/*/.config/`, `profiles/*/list/`, `*.sqlite3` |

---

## Per-Component Technical Docs

### bin/
- [bin/ww](bin/ww.md) — Main CLI dispatcher
- [bin/ww-init.sh](bin/ww-init.md) — Shell bootstrap

### lib/
- [core-utils.sh](lib/core-utils.md)
- [profile-manager.sh](lib/profile-manager.md)
- [shell-integration.sh](lib/shell-integration.md)
- [logging.sh](lib/logging.md)
- [github-api.sh](lib/github-api.md)
- [sync-pull.sh + sync-push.sh](lib/sync-pull-push.md)
- [field-mapper.sh](lib/field-mapper.md)
- [sync-detector.sh + github-sync-state.sh](lib/sync-detector-state.md)
- [sync-permissions.sh](lib/sync-permissions.md)
- [taskwarrior-api.sh](lib/taskwarrior-api.md)
- [config-utils.sh](lib/config-utils.md)
- [bugwarrior-integration.sh](lib/bugwarrior-integration.md)
- [export-utils.sh](lib/export-utils.md)
- [delete-utils.sh](lib/delete-utils.md)
- [profile-stats.sh](lib/profile-stats.md)
- [shortcode-registry.sh](lib/shortcode-registry.md)
- [dependency-installer.sh](lib/dependency-installer.md)

### services/ — top-level
- [github-sync.sh](services/github-sync.md)
- [profile-uda.sh](services/profile-uda.md)
- [profile-urgency.sh](services/profile-urgency.md)
- [questions/q.sh](services/questions.md)

### services/profile/
- [create-ww-profile.sh](services/profile/create-ww-profile.md)
- [manage-profiles.sh](services/profile/manage-profiles.md)

### services/custom/
- [configure-issues.sh](services/custom/configure-issues.md)

### services/extensions/
- [extensions.sh](services/extensions/extensions.md)

### services/find/
- [find.sh + find.py](services/find/find.md)

### services/groups/
- [groups.sh](services/groups/groups.md)

### services/models/
- [models.sh](services/models/models.md)

### services/export/
- [export.sh](services/export/export.md)

### services/browser/
- [server.py + static/*](services/browser/browser.md) — Browser UI, CMD AI, heuristic engine

### services/ctrl/
- [ctrl.sh](services/ctrl/ctrl.md) — AI mode, prompt, UI settings

### scripts/
- [compile-heuristics.py](scripts/compile-heuristics.md) — Heuristic compilation system

### weapons/
- [gun/](weapons/gun.md) — taskgun passthrough
- [sword/](weapons/sword.md) — Task splitting into sequential subtasks

### cross-cutting/ — broad functionality originating in specific services
- [installer-utils.sh](cross-cutting/installer-utils.md) — install infrastructure
- [config-loader.sh](cross-cutting/config-loader.md) — GitHub sync config loading
- [error-handler.sh](cross-cutting/error-handler.md) — GitHub error classification

### cross-cutting/sync-engine/ — full sync subsystem
- [overview.md](cross-cutting/sync-engine/overview.md) — full cycle, file map, data integrity fixes
- [conflict-resolver.sh](cross-cutting/sync-engine/conflict-resolver.md)
- [annotation-sync.sh](cross-cutting/sync-engine/annotation-sync.md)
- [sync-bidirectional.sh](cross-cutting/sync-engine/sync-bidirectional.md)

## Changelog

- 2026-04-12 — Added browser UI, CMD AI, heuristic engine, CTRL service, weapons (gun/sword), compile-heuristics, clark profile, updated architecture overview
- 2026-04-10 — Initial version
