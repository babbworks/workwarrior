# Handover Document — Kiro → Codex
# Date: 2026-04-11

## Project State

Workwarrior is a profile-based productivity system wrapping TaskWarrior, TimeWarrior,
jrnl, and hledger. It has a CLI (`bin/ww`) and a browser UI (`services/browser/`).

**Phase:** Phase 2 (active development). Phase 1 (foundation) is complete.

**Card counts:** 56 complete, 11 pending, 4 parked, 1 deferred, 1 in-progress. Total: 73.

## Key Files to Read First

1. `system/CLAUDE.md` — project rules, gates, fragility register
2. `system/TASKS.md` — dispatch board with priority queue
3. `system/tasks/INDEX.md` — complete card inventory with one-line summaries
4. `system/logs/decisions.md` — all architectural decisions
5. `system/logs/session-browser-ui.md` — detailed log of this session's 52 changes
6. `system/audits/divergences.md` — behavioral differences from upstream tools

## What Was Built This Session

### Browser UI (services/browser/)
- Full sidebar with 15+ service panels (Tasks, Times, Journals, Ledgers, Next,
  Schedule, Sync, Groups, Models, Network, Export, Questions, Saves, Projects, CMD, CTRL)
- Task inline editor with UDA support (add/edit UDAs, service UDAs read-only)
- Task start/stop/done buttons (fixed: server always returns ok:true with refreshed list)
- Time tracking with structured tags + journal description
- Hledger integration (10 report types, period/filter/depth controls)
- CMD AI with ollama integration (simplified prompt for small models, heuristic parser)
- AI access controls in CTRL panel (off/local-only/local+remote)
- Resource creation for all 4 function types (journals, ledgers, tasklists, timew)
- Profile management (dropdown, P button, warrior stats)

### CLI (bin/ww)
- `ww q` / `ww questions` — template-based workflows with UDA picker
- `ww sword` — task splitting into sequential subtasks with dependencies
- `ww gun` — bulk task series (taskgun passthrough)
- Questions profile resolution fixed (reads active_profile state file)

### Project Organization
- `/weapons/` folder with README, gun/, sword/ subdirectories
- `system/tasks/INDEX.md` — scannable card registry with priority queue
- `config/ai.yaml` — AI access control configuration
- `config/projects.yaml` — project definitions
- `services/servers/README.md` — TaskChampion sync service spec
- `services/projects/README.md` — cross-cutting project views
- `services/cmd/README.md` — unified command service with JSONL log
- `docs/taskwarrior-extensions/timewarrior-extensions.md` — 59 repos catalogued

### Key Decisions (see system/logs/decisions.md)
- Orchestrator bypass justified for LOW fragility browser files
- Simultaneous time tracking: multiple TIMEWARRIORDB approach (deferred)
- Projects: cross-cutting views, not a new data store
- Weapons: top-level concept, gun=extension, sword=native
- AI: simplified prompt for small LLMs, heuristic command parsing
- Recurring tasks: TW built-in + extend to journals/ledgers
- TimeWarrior extensions: sync + billable (user selected)
- Calendar: parked
- WEB-001: archived (superseded by browser service)

## What Needs Doing Next (Priority Order)

1. **TASK-QUAL-002** (NEXT) — Automate docs/help parity checks. Gate C enforcement.
2. **TASK-ISSUES-001** (HIGH) — Fix `i uda` to read service-uda-registry.yaml.
   Fix `i status` to route to github-sync, not bugwarrior.
3. **TASK-SITE-006** (MEDIUM) — Export download button, keyboard shortcuts, typeahead.
4. **TASK-UX-001** (MEDIUM) — Standardize human/compact/json output across all commands.
5. **TASK-UX-002** (MEDIUM) — Command examples in help text AND docs/examples/.
6. **TASK-TIMEW-001** (MEDIUM) — TimeWarrior extension manager (sync + billable).
7. **TASK-DESIGN-001** (MEDIUM) — Quiz user about unimplemented service categories.

## Known Issues

- Profile names with dashes (e.g., `my-project`) may cause quoting issues in some CLI paths
- `hledger` must be in PATH when browser server starts (fixed with PATH augmentation)
- Small LLMs (1-3B params) produce inconsistent command formats — heuristic parser handles this
- The `functions/` directory has dead code that should be cleaned up
- `i status` and `i help` produce Python tracebacks from bugwarrior

## Fragility Register

| File(s) | Classification |
|---|---|
| `lib/github-*.sh`, `lib/sync-*.sh`, `services/custom/github-sync.sh` | HIGH FRAGILITY |
| `bin/ww`, `lib/shell-integration.sh` | SERIALIZED |
| `services/browser/static/*`, `services/browser/server.py` | LOW |

## Process Notes

- The `/system` orchestrator workflow (Explorer → Builder → Verifier) should be used
  for HIGH FRAGILITY and SERIALIZED files
- Browser UI changes can be done directly (LOW fragility) with compile checks
- All decisions must be logged in `system/logs/decisions.md`
- Task cards follow the template in `system/templates/task-card.md`
- `system/tasks/INDEX.md` is the scannable inventory; `system/TASKS.md` is the dispatch board
