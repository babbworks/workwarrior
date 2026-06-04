# Task Card Index

Last updated: 2026-05-02 (TASK-INSTALL-003 added — installer v0.2 multi-instance + 5 basic-install bug fixes)
Total: 115 task cards in `tasks/cards/`. Card `Status:` field is authoritative; this file is a scannable index.

## Priority Queue

| Priority | Card | Goal |
|----------|------|------|
| HIGH | TASK-SITE-040 | Journal cross-journal entry link fix |
| HIGH | TASK-SITE-041 | Archive view button — browse/restore archived entries |
| MEDIUM | TASK-SITE-039 | Journal markdown rendering with toggle (browser UI) |
| MEDIUM | TASK-SITE-042 | CMD log UI — collapse/clear/dismiss entries |
| MEDIUM | TASK-RES-001 | Ledger account/commodity inventory (cross-profile) |
| MEDIUM | TASK-RES-002 | UDA inventory (cross-profile .taskrc aggregate) |
| MEDIUM | TASK-TEST-003 | Harden browser BATS suites for CI isolation |
| MEDIUM | TASK-AGENT-001 | Canonical agent-templates in resources/ |
| LOW | TASK-CI-001 | Re-enable GitHub Actions (depends TEST-003) |
| HIGH | TASK-SITE-011 | ~~Remove alert()/prompt() — inline UI~~ **complete** |
| HIGH | TASK-SITE-012 | ~~Toast notification system~~ **complete** |
| HIGH | TASK-SITE-015 | ~~Keyboard shortcuts — g+key nav + ? overlay~~ **complete** |
| HIGH | TASK-SITE-017 | ~~Task grouping by project + overdue float~~ **complete** |
| HIGH | TASK-SITE-021 | ~~Active task persistent header indicator~~ **complete** |
| HIGH | TASK-SITE-022 | ~~Second + ms time display granularity~~ **complete** |
| HIGH | TASK-SITE-032 | ~~Groups panel inline view~~ **complete** |
| MEDIUM | TASK-SITE-013 | ~~Error states with retry buttons~~ **complete** |
| MEDIUM | TASK-SITE-016 | ~~Global search tasks + journals~~ **complete** |
| MEDIUM | TASK-SITE-018 | ~~Type-aware UDA inputs~~ **complete** |
| MEDIUM | TASK-SITE-019 | ~~Scheduled + wait fields in task form~~ **complete** |
| MEDIUM | TASK-SITE-020 | ~~Bulk task operations~~ **complete** |
| MEDIUM | TASK-SITE-023 | ~~Previous/next week navigation in time~~ **complete** |
| MEDIUM | TASK-SITE-025 | ~~Journal date grouping + pagination~~ **complete** |
| MEDIUM | TASK-SITE-026 | ~~Sync panel dashboard~~ **complete** |
| MEDIUM | TASK-SITE-027 | ~~Models panel structured list~~ **complete** |
| MEDIUM | TASK-SITE-028 | ~~Questions run-template from UI~~ **complete** |
| MEDIUM | TASK-SITE-030 | ~~Profile screen structured stats~~ **complete** |
| MEDIUM | TASK-SITE-031 | ~~Warrior aggregate urgency view~~ **complete** |
| LOW | TASK-SITE-014 | ~~Section scroll position memory~~ **complete** |
| LOW | TASK-SITE-024 | ~~Time entry tag format clarity~~ **complete** |
| LOW | TASK-SITE-029 | ~~BookBuilder real integration~~ **complete** |
| LOW | TASK-SITE-033 | ~~Sword panel task search~~ **complete** |
| LOW | TASK-SITE-034 | ~~Live data refresh via SSE + polling~~ **complete** |
| LOW | TASK-EXT-CAL-001 | Calendar integration (parked) |
| COMPLETE | TASK-EXT-WARLOCK-001 | ~~task-warlock Next.js UI adoption~~ **complete** |
| PARKED | TASK-TC-001 | TaskChampion multi-device sync |

## In-Progress (0)

- _(none)_

## Pending (8)

- **TASK-EXT-GUN-001-EXPLORE** — Read-only audit of taskgun source to answer the five limitations
- **TASK-EXT-SWORD-001** — Define and build the Sword weapon — a second sidebar weapon
- **TASK-LED-001** — Ledger transaction row redesign: 3-line item UI (primary row, metadata expand, persistent comment button)
- **TASK-LED-002** — Agent/session ledger account hierarchy + session recording process (time:, sessions:, costs:, output:)
- **TASK-LED-003** — Modular journal files and hledger include strategy for profile resources
- **TASK-SITE-001** — Deliver a locally-served, terminal-aesthetic web interface for Workwarrior
- **TASK-SITE-006** — Complete the browser service with static export, a redesigned terminal
- **TASK-SITE-035** — Lists service stabilization (save reliability, multi-list UX, inline controls)

## Complete (added 2026-05-02)

- **TASK-INSTALL-004** — Per-anchor bootstrap guard: `WW_BOOTSTRAP_LOADED` → `WW_BOOTSTRAP_LOADED_<CMD>` so multiple multi-anchors can coexist in one shell
- **TASK-INSTALL-003** — Installer v0.2: multi-instance architecture (6 presets, @instance dispatch, companion activation functions, ww pin/unpin, main→default rename, 5 bug fixes for standalone installs)

## Complete (added 2026-04-25)

- **TASK-SITE-036** — Tags screen: function-group nav, tag cards with chip filters (status/priority/UDA), exclude toggle, sort modes, date display
- **TASK-SITE-037** — Task dependency display: ⊸N/→N row badges, dep section in inline detail, dep_add/dep_remove server actions (depends+/- syntax)
- **TASK-SITE-038** — Header restructure: unified resource slot adjacent to title, active-task-pill (green bar) removed, stat-context-bar removed, section-resource-bars removed from all sections

## Complete (87)

*Bullets below are a partial roll-up; any card with `Status: complete` in `tasks/cards/` counts toward this total.*

- **TASK-1.1** — Copy devsystem CLAUDE.md to project root so all agents can cold-start.
- **TASK-1.2** — Copy devsystem services-CLAUDE.md so Builder agents can write correct
- **TASK-1.3a** — Produce a contradiction matrix categorizing every completion claim
- **TASK-1.3b** — Produce a test coverage map, code-vs-doc gap list, and required
- **TASK-1.4** — Synthesize Explorer A + B outputs into a fully populated project
- **TASK-1.5** — Ensure .gitignore excludes all generated artifacts so future PRs
- **TASK-AI-001** — The CMD AI feature fails because small local LLMs (gemma3:1b,
- **TASK-CLI-001** — Standardize the global command model as `ww <domain> <verb> [args]`.
- **TASK-CLI-002** — Implement consistent handling of `--profile`, `--global`, `--json`, `--compact`, `--verbos
- **TASK-CLI-003** — Make help text uniform in structure, examples, and flag documentation across commands.
- **TASK-CLI-004** — Preserve legacy command forms while nudging users to preferred syntax.
- **TASK-DESIGN-001** — Service overview stubs for undeveloped service categories (design-only).
- **TASK-TIMEW-001** — Per-profile `ww timew extensions` + timew-billable integration doc.
- **TASK-QUAL-002** — `check-parity.sh`: CSSOT syntax vs mapped `ww … help` (Gate C automation).
- **TASK-ISSUES-001** — ww-native `issues uda` subcommands + idempotent install + github group shortcut.
- **TASK-SITE-007** — Browser UI overhaul meta-card closed; residual scope migrated into TASK-SITE-006.
- **TASK-UX-001** — Compact-default output policy + `--json` support consistency across core read/list flows.
- **TASK-UX-002** — Approved examples library per command family + verifier example-validation checklist.
- **TASK-EXT-CRON-001** — `ww routines` recurring-task microservice with profile-scoped `.config/routines` storage.
- **TASK-EXT-CHECK-001** — Surface taskcheck as `ww schedule` — an automatic task scheduler
- **TASK-EXT-DENSITY-001** — Add due-date density scoring to ww profiles. TWDensity adds a
- **TASK-EXT-GUN-001** — Surface taskgun as `ww gun` for generating deadline-spaced task
- **TASK-EXT-SCHED-001** — Surface the CFS-inspired next-task selector as `ww next` —
- **TASK-EXT-SWORD-002** — Sword splits a single task into N subtasks with sequential
- **TASK-INSTALL-002** — The `journals` bare command displayed config keys (body, date, tags, title,
- **TASK-MCP-001** — Wrap hnsstrk/taskwarrior-mcp as ww mcp — an MCP server that exposes
- **TASK-QUAL-001** — Prevent generated/local artifacts from polluting diffs and tracked history.
- **TASK-QUAL-003** — Explorer B found functions/issues/taskwarriortogithubissue.sh is unreferenced
- **TASK-QUAL-004** — filter_system_tags() builds its jq filter using `. |` instead of
- **TASK-REL-001** — Make release-readiness claims impossible without checklist completion evidence.
- **TASK-REL-002** — Establish measurable criteria for declaring Workwarrior CLI production-ready.
- **TASK-SHELL-001** — bin/ww has only `set -e`. All 24 lib/ files and all 6 services/custom/ scripts
- **TASK-SHELL-UX-001** — Multiple shell integration pain points addressed in one batch:
- **TASK-SITE-002** — Stand up the browser service skeleton: Python3 HTTP server with SSE
- **TASK-SITE-003** — Replace the Wave 1 placeholder HTML with a real UI shell: dark
- **TASK-SITE-004** — Replace skeleton placeholders in all four sections (Tasks, Time,
- **TASK-SITE-005** — Polish the three remaining data sections (Time, Journal, Ledger),
- **TASK-SITE-008** — The start, stop, and done buttons on task rows in the browser
- **TASK-SITE-009** — Clicking an item in the Times recent intervals list should
- **TASK-SITE-010** — When clicking a task to expand its inline detail, the user
- **TASK-SVC-001** — Deliver `ww journal|journals add/list/remove/rename` with preferred singular namespace and
- **TASK-SVC-002** — Deliver `ww ledger add/list/remove/rename` for multi-ledger profile workflows.
- **TASK-SVC-003** — Implement discoverable `ww service list/info/help` flows so users can navigate services fr
- **TASK-SVC-004** — Complement profile backup with safe import/restore commands.
- **TASK-SVC-005** — Normalize `q`/questions behavior, template lifecycle, and errors for reliable daily use.
- **TASK-SVC-006** — Align `i` and `ww` issues/sync command routing, messaging, and scope behavior.
- **TASK-SVC-007** — Build `ww remove` service for clean profile removal with archive/delete/scrub.
- **TASK-SYNC-001** — The entire sync engine (6 files, 17 functions) has zero BATS tests.
- **TASK-SYNC-002** — Three specific bugs found by Explorer B can silently corrupt or permanently
- **TASK-SYNC-003** — Sync operations currently make silent assumptions about environment
- **TASK-SYNC-004** — Resolved Gate E tag-sync TODO in `sync-pull.sh`; follow-up label sync in TASK-SYNC-005
- **TASK-SYNC-005** — sync-pull.sh currently skips tag sync during pull. GitHub labels are not
- **TASK-SYNC-006** — The current label sync only handles priority and generic tag pass-through.
- **TASK-SYNC-007** — Rich TaskWarrior UDAs (goals, deliverables, scope description,
- **TASK-SYS-001** — Make `/Users/mp/ww/system` the single active operating system for project development.
- **TASK-SYS-002** — Ensure Phase-1 verification reports only real blockers and clearly distinguishes structura
- **TASK-SYS-003** — Establish one canonical specification for commands, subcommands, flags, and examples acros
- **TASK-TEST-001** — Make required test suites enforceable from task metadata and change classification.
- **TASK-TEST-002** — Run required tests automatically on PRs based on change type and block merges on failure.
- **TASK-TUI-001** — Wrap kdheepak/taskwarrior-tui as a first-class ww command with
- **TASK-UDA-001** — Wire uda-manager.sh as ww profile uda manage. Build the full
- **TASK-UDA-002** — Define a systematic unicode character scheme for UDA indicators,
- **TASK-UDA-003** — Implement a ww-wide color convention for UDA fields that maps
- **TASK-URG-001** — Surface TaskWarrior's urgency scoring system through a ww-native
- **TASK-WWCTL-001** — Transform wwctl from a 6-command task-lifecycle tool into a

## Parked (4)

- **TASK-EXT-CAL-001** — Integrate calendar and/or reminders into ww profiles. Scope is
- **TASK-EXT-CRON-001** — Surface allgreed/cron as `ww routines` — a stateful recurring task
- **TASK-TC-001** — Design and implement ww's approach to reliable multi-device
- **TASK-WEB-001** — Build or adopt a locally-served web interface for ww that provides

## Deferred (1)

- **TASK-ISSUES-002** — Only one profile has bugwarrior configured. Additional
