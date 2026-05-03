# Workwarrior Documentation

Workwarrior is a profile-based productivity system that unifies TaskWarrior, TimeWarrior, JRNL, and Hledger under a single CLI and browser UI.

→ **[Why Work Warrior](whyworkwarrior.md)**

---

## Getting Started

| Page | Description |
|------|-------------|
| [Getting Started](guides/getting-started.md) | Install, first profile, basic usage |
| [Installation](guides/install.md) | Platform notes, dependency management |
| [Profiles](guides/profiles.md) | Isolation, resources, UDAs, backup, removal |

## Core Usage

| Page | Description |
|------|-------------|
| [Commands](guides/commands.md) | Full command surface and shell functions |
| [Usage Examples](guides/usage-examples.md) | Practical workflows |
| [Browser Integration](guides/browser.md) | Web interface, CMD input, panels, API |
| [Heuristics](guides/heuristics.md) | Natural language, 627+ rules, self-improvement |
| [Weapons](guides/weapons.md) | Gun, Sword, Next, Schedule |
| [Services](guides/services.md) | Overview of all service domains |
| [Architecture](guides/architecture.md) | Directory structure, env vars, internals |

## GitHub Sync

| Page | Description |
|------|-------------|
| [GitHub Sync Guide](guides/github-sync-guide.md) | Two-way sync walkthrough |
| [GitHub Sync Configuration](guides/github-sync-configuration.md) | Setup and config reference |
| [GitHub Sync Troubleshooting](guides/github-sync-troubleshooting.md) | Common issues and fixes |
| [Issues & Troubleshooting](guides/issues-troubleshooting.md) | Bugwarrior debugging |

## Search Guides

| Tool | Guide |
|------|-------|
| Tasks | [guides/search/task.md](guides/search/task.md) |
| Time | [guides/search/time.md](guides/search/time.md) |
| Journals | [guides/search/journal.md](guides/search/journal.md) |
| Ledgers | [guides/search/ledger.md](guides/search/ledger.md) |
| Lists | [guides/search/list.md](guides/search/list.md) |

## Development

| Page | Description |
|------|-------------|
| [Service Development](guides/service-development.md) | Build and register services |
| [Testing Guide](guides/testing-guide.md) | Manual testing procedures |
| [Release Checklist](guides/release-checklist.md) | Production readiness gates |

## Technical Reference

Per-component documentation for every library, service, and subsystem.

| Section | Description |
|---------|-------------|
| [Binaries](reference/bin/) | `ww` dispatcher and `ww-init.sh` bootstrap |
| [Core Libraries](reference/lib/) | 17+ core libraries (profile-manager, sync engine, logging, etc.) |
| [Services](reference/services/) | All services (github-sync, UDA, urgency, questions, groups, models, etc.) |
| [Cross-Cutting](reference/cross-cutting/) | Sync engine, conflict resolver, annotation sync, installer, config loader |
| [Extensions](reference/extensions/) | TaskWarrior & TimeWarrior extensions |
| [Source Map](reference/source-map.yaml) | Maps each doc to its source files |

---

**Recommended starting point**: Begin with **[Why Work Warrior](whyworkwarrior.md)** for the vision and motivation, then move to [Getting Started](guides/getting-started.md).