# Task Card Index

Last updated: 2026-04-11 11:04
Total: 73 cards

## Priority Queue

| Priority | Card | Goal |
|----------|------|------|
| NEXT | TASK-QUAL-002 | Automate docs/help parity checks (Gate C) |
| HIGH | TASK-ISSUES-001 | Fix ww issues uda routing |
| HIGH | TASK-SITE-007 | Browser UI completion (ongoing) |
| MEDIUM | TASK-SITE-006 | Wave 5: export, typeahead, keyboard shortcuts |
| MEDIUM | TASK-UX-001 | Standardize human/compact/json output modes |
| MEDIUM | TASK-UX-002 | Command examples library (help + docs) |
| MEDIUM | TASK-TIMEW-001 | TimeWarrior extension manager (sync + billable) |
| MEDIUM | TASK-DESIGN-001 | Service category design quiz |
| LOW | TASK-EXT-CAL-001 | Calendar integration (parked) |
| LOW | TASK-EXT-CRON-001 | Recurring tasks via TW + journals/ledgers |
| PARKED | TASK-TC-001 | TaskChampion multi-device sync |
| PARKED | TASK-EXT-WARLOCK-001 | task-warlock Next.js UI adoption |

## In-Progress (1)

- **TASK-SITE-007** — Transform the browser UI from a basic data viewer into a full

## Pending (11)

- **TASK-DESIGN-001** — Quiz the user about each service category that has no implementation yet.
- **TASK-EXT-GUN-001-EXPLORE** — Read-only audit of taskgun source to answer the five limitations
- **TASK-EXT-SWORD-001** — Define and build the Sword weapon — a second sidebar weapon
- **TASK-EXT-WARLOCK-001** — Adopt task-warlock (Next.js web UI) as the foundation for ww's
- **TASK-ISSUES-001** — `ww issues uda` currently passes through directly to bugwarrior's own `uda`
- **TASK-QUAL-002** — Enforce Gate C by detecting mismatch between command behavior, help text, and docs/CSSOT.
- **TASK-SITE-001** — Deliver a locally-served, terminal-aesthetic web interface for Workwarrior
- **TASK-SITE-006** — Complete the browser service with static export, a redesigned terminal
- **TASK-TIMEW-001** — Add ww timew extensions as a per-profile TimeWarrior extension manager.
- **TASK-UX-001** — Default to compact human output while enabling explicit `--json` for review/automation use
- **TASK-UX-002** — Provide validated examples for every major command family to reduce adoption friction.

## Complete (56)

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
- **TASK-SYNC-004** — lib/sync-pull.sh:100 contains `# TODO: Implement proper tag sync` with no
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
