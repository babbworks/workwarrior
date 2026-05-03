# ww-standard

The canonical technical reference for [Workwarrior](https://workwarrior.org) — a profile-based productivity system that wraps TaskWarrior, TimeWarrior, JRNL, Hledger, and Bugwarrior into a single CLI and browser UI.

This repository ships with Workwarrior as its technical documentation. It is also the standard against which conformance is measured and the place where changes to the system are proposed and ratified.

---

## What This Repository Contains

| Path | What It Is |
|------|-----------|
| [`WORKWARRIOR-STANDARD.md`](WORKWARRIOR-STANDARD.md) | Normative technical standard — 24 sections, fully spec'd |
| [`whyworkwarrior.md`](whyworkwarrior.md) | The design philosophy — why this exists and what it's for |
| [`summary.md`](summary.md) | Full document index with links to every guide and reference |
| [`docs/`](docs/) | Human-readable overviews for each major subsystem |
| [`guides/`](guides/) | Walkthrough guides for installation, profiles, sync, and more |
| [`reference/`](reference/) | Per-file technical documentation for every lib, service, and binary |

---

## Start Here

**If you just installed Workwarrior:**
→ [`guides/starting/getting-started.md`](guides/starting/getting-started.md)

**If you want to understand the system architecture:**
→ [`docs/architecture.md`](docs/architecture.md) for the overview  
→ [`WORKWARRIOR-STANDARD.md`](WORKWARRIOR-STANDARD.md) §2–§8 for the full spec

**If you want to build a service or extension:**
→ [`guides/services/service-development.md`](guides/services/service-development.md)

**If you want to understand the GitHub sync engine:**
→ [`guides/github/github-sync-guide.md`](guides/github/github-sync-guide.md)  
→ [`WORKWARRIOR-STANDARD.md`](WORKWARRIOR-STANDARD.md) §14 for the normative spec

**If you're looking for a specific file:**
→ [`reference/source-map.yaml`](reference/source-map.yaml) maps every doc to its source

---

## The Normative Standard

[`WORKWARRIOR-STANDARD.md`](WORKWARRIOR-STANDARD.md) is the single authoritative technical description of how Workwarrior is built. It covers:

1. Overview and architecture
2. Complete directory structure with every file annotated
3. Environment variables — what they are, who sets them, who reads them
4. Profile model — structure, lifecycle, isolation guarantees
5. Shell bootstrap — ww-init.sh, injected functions, rc file management
6. CLI dispatcher — routing, service discovery, security constraints
7. All 24 core library files — role, key functions, constraints
8. Service architecture — the contract every service must follow
9. Full service registry — all 25+ domains
10. Browser UI — server implementation, API endpoints, security model
11. Heuristic engine — 627 rules, 19 domains, compiler, self-improvement loop
12. AI integration — modes, provider registry, per-profile override
13. GitHub sync engine — both engines, field mapping, conflict resolution
14. Weapons system — Sword, Gun, Next, Schedule
15. UDA system — types, source classification, sync permissions
16. Extensions, questions, export
17. Fragility register — HIGH/SERIALIZED/NEVER COMMIT classifications
18. Shell coding standards — enforced at Gate B
19. Testing policy
20. Install policy and dependency table

---

## System Overview

Workwarrior is as open source as it gets. A CLI layer and browser layer on top of tools that are already excellent:

```
taskwarrior  →  task management, UDAs, urgency engine, hooks
timewarrior  →  time tracking, intervals, reports
jrnl         →  journal entries, multi-journal, date search
hledger      →  double-entry accounting, balance sheets
bugwarrior   →  issue pull from GitHub, GitLab, Jira, and 20+ more
               ↓
              ww
               ↓
   profile isolation + unified CLI + browser UI
   natural language + GitHub sync + weapons + extensions
```

The integration layer adds what didn't exist between the tools. The tools themselves are unchanged.

Formal-cause framing: **Composable Local Service Architecture**.

### Profile Isolation

A profile is a directory. Activating it sets five environment variables. Every tool reads those variables. No tool knows Workwarrior exists.

```bash
ww profile create work
p-work                         # exports TASKRC, TASKDATA, TIMEWARRIORDB, etc.

task add "Ship API" due:friday # writes to profiles/work/.task/
j "Sprint 12 kicked off"       # writes to profiles/work/journals/
l balance                      # reads profiles/work/ledgers/
```

Switching contexts: `p-personal`. Switching back: `p-work`. No reconfiguration. No data overlap.

### Natural Language Without AI

627 compiled heuristic rules handle routine commands without a network call:

```
"add a task to review the budget due friday"  →  task add review the budget due:friday
"start tracking time on code review"          →  timew start code review
"finish task 5 and stop tracking"             →  task 5 done
                                                 timew stop
```

AI is optional. It adds flexibility for phrasings the heuristics don't cover. The heuristic engine gets better over time — every AI hit can be compiled into a new rule.

### The Browser UI

```bash
ww browser      # localhost:7777, no npm, Python 3 stdlib only
```

15+ panels. Tasks, time, journals, ledgers, CMD, GitHub sync, weapons, AI controls. Server-Sent Events for real-time updates. Security boundary: `ALLOWED_SUBCOMMANDS` frozenset validates every command execution.

---

## Document Map

### Getting Started

| Document | Description |
|----------|-------------|
| [Getting Started](guides/starting/getting-started.md) | Install, first profile, first commands |
| [Installation](guides/starting/install.md) | Platform notes, dependency management, `ww deps` |
| [Commands](guides/starting/commands.md) | Full command surface and shell functions |
| [Usage Examples](guides/starting/usage-examples.md) | Practical workflows |

### Core Concepts

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture.md) | Data flow, environment variables, fragility register |
| [Profiles](docs/profiles.md) | Isolation, multiple resources, UDAs, backup/restore |
| [Services](docs/services.md) | All 25+ service domains, service contract, building new services |
| [Weapons](docs/weapons.md) | Sword, Gun, Next, Schedule — task manipulation tools |

### Features

| Document | Description |
|----------|-------------|
| [Heuristic Engine](docs/heuristics.md) | 627 rules, 6 phrasing variations, compiler, self-improvement |
| [Browser UI](docs/browser-ui.md) | Panels, CMD routing, REST API, SSE, security |
| [GitHub Sync](docs/github-sync.md) | Bugwarrior pull + bidirectional task↔issue sync |
| [AI Integration](docs/ai-integration.md) | Modes, providers, per-profile override |
| [UDA System](docs/uda-system.md) | Types, source badges, sync permissions, urgency tuning |

### GitHub Sync (Detailed Guides)

| Document | Description |
|----------|-------------|
| [Sync Guide](guides/github/github-sync-guide.md) | Full walkthrough |
| [Configuration](guides/github/github-sync-configuration.md) | Setup and config reference |
| [Troubleshooting](guides/github/github-sync-troubleshooting.md) | Common issues and fixes |
| [Testing](guides/github/testing-guide.md) | Test procedures for sync changes |

### Search Guides

| Tool | Guide |
|------|-------|
| Tasks | [guides/search/task.md](guides/search/task.md) |
| Time | [guides/search/time.md](guides/search/time.md) |
| Journals | [guides/search/journal.md](guides/search/journal.md) |
| Ledgers | [guides/search/ledger.md](guides/search/ledger.md) |
| Lists | [guides/search/list.md](guides/search/list.md) |

### Development

| Document | Description |
|----------|-------------|
| [Service Development](guides/services/service-development.md) | Build and register new services |
| [Release Checklist](guides/releases/release-checklist.md) | Production readiness gates |
| [Issues Troubleshooting](guides/issues/issues-troubleshooting.md) | Bugwarrior debugging |

### Technical Reference (Per-File)

| Section | Description |
|---------|-------------|
| [`reference/bin/`](reference/bin/) | `ww` dispatcher and `ww-init.sh` bootstrap |
| [`reference/lib/`](reference/lib/) | All 24 core library files |
| [`reference/services/`](reference/services/) | Every service directory documented |
| [`reference/cross-cutting/`](reference/cross-cutting/) | Sync engine, config loader, error handler, installer |

---

## Fragility Register

The standard explicitly classifies the highest-risk parts of the codebase. Changes to these files require an extended risk brief and adversarial verification before merge:

| Classification | Files |
|----------------|-------|
| **HIGH FRAGILITY** | `lib/github-api.sh`, `lib/sync-pull.sh`, `lib/sync-push.sh`, `lib/sync-bidirectional.sh`, `lib/field-mapper.sh`, `lib/sync-detector.sh`, `lib/conflict-resolver.sh`, `lib/annotation-sync.sh`, `lib/github-sync-state.sh`, `services/custom/github-sync.sh` |
| **SERIALIZED** | `bin/ww`, `lib/shell-integration.sh` |
| **NEVER COMMIT** | `profiles/*/` data files, `*.sqlite3` |

The sync engine operates on data in two external systems simultaneously. Getting it wrong means irreversible data loss. The fragility classification is not bureaucracy — it's proportionate to the failure modes.

---

## Shell Standards

Every script in the project starts with:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

No exceptions. Violations are Gate B failures. Full standards in [`WORKWARRIOR-STANDARD.md`](WORKWARRIOR-STANDARD.md) §21.

---

## Proposing Changes

This repository is the standard. Changes to how Workwarrior works — architecture, service contracts, sync behavior, shell standards — are proposed here.

1. Open an issue with the `proposal` label describing the change, its rationale, and known implementation implications
2. Reference the specific section of `WORKWARRIOR-STANDARD.md` affected
3. If applicable, include a draft of the updated normative text
4. Babb reviews and either accepts, requests revision, or declines with reasoning

Changes to HIGH FRAGILITY components require a trial implementation with documented results before ratification.

---

## Acknowledgements

Workwarrior wraps these projects. They do the work. We wire them together.

- [TaskWarrior](https://taskwarrior.org) — Göteborg Bit Factory
- [TimeWarrior](https://timewarrior.net) — Göteborg Bit Factory
- [JRNL](https://jrnl.sh) — open source
- [Hledger](https://hledger.org) — Simon Michael
- [Bugwarrior](https://github.com/GothenburgBitFactory/bugwarrior) — Göteborg Bit Factory
- [taskgun](https://github.com/hamzamohdzubair/taskgun) — Hamza Mohd Zubair
- [taskwarrior-tui](https://github.com/kdheepak/taskwarrior-tui) — Dheepak Krishnamurthy
- [taskwarrior-mcp](https://github.com/hnsstrk/taskwarrior-mcp) — hnsstrk

---

**Workwarrior** · Made by [Babb](https://babb.tel) · [workwarrior.org](https://workwarrior.org) · ww@babb.tel
