# Workwarrior Project

Workwarrior is a profile-based productivity system that unifies TaskWarrior, TimeWarrior, JRNL, and Hledger under a single CLI and browser UI.

→ **[Why Work Warrior](whyworkwarrior.md)**

---

## Getting Started

| Page                  | Description                                      |
|-----------------------|--------------------------------------------------|
| [Getting Started](guides/starting/getting-started.md) | Install, first profile, basic usage |
| [Installation](guides/starting/install.md)            | Platform notes, dependency management |
| [Commands](guides/starting/commands.md)               | Full command surface and shell functions |
| [Usage Examples](guides/starting/usage-examples.md)   | Practical workflows |

## Profiles & Core Concepts

| Page                        | Description                                      |
|-----------------------------|--------------------------------------------------|
| [Profiles](guides/profiles/profiles.md)          | Isolation, resources, UDAs, backup, removal     |
| [Architecture](guides/architecture.md)           | Directory structure, env vars, internals        |
| [Services](guides/services/services.md)          | Overview of all service domains                 |
| [Weapons](guides/weapons/weapons.md)             | Gun, Sword, Next, Schedule                      |
| [Heuristics](guides/heuristics/heuristics.md)    | Natural language, 627+ rules, self-improvement  |
| [Browser Integration](guides/browser/browser.md) | Web interface, CMD input, panels, API           |

## GitHub Sync

| Page                                      | Description                                      |
|-------------------------------------------|--------------------------------------------------|
| [GitHub Sync Guide](guides/github/github-sync-guide.md)              | Two-way sync walkthrough |
| [GitHub Sync Configuration](guides/github/github-sync-configuration.md) | Setup and config reference |
| [GitHub Sync Troubleshooting](guides/github/github-sync-troubleshooting.md) | Common issues and fixes |
| [Testing Guide](guides/github/testing-guide.md)                      | Testing procedures |

## Search Guides

| Tool      | Guide |
|-----------|-------|
| Tasks     | [guides/search/task.md](guides/search/task.md) |
| Time      | [guides/search/time.md](guides/search/time.md) |
| Journals  | [guides/search/journal.md](guides/search/journal.md) |
| Ledgers   | [guides/search/ledger.md](guides/search/ledger.md) |
| Lists     | [guides/search/list.md](guides/search/list.md) |

## Development & Releases

| Page                              | Description                                      |
|-----------------------------------|--------------------------------------------------|
| [Service Development](guides/services/service-development.md) | Build and register services |
| [Release Checklist](guides/releases/release-checklist.md)     | Production readiness gates |
| [Issues & Troubleshooting](guides/issues/issues-troubleshooting.md) | Bugwarrior debugging |

## Technical Reference

Per-component documentation for every library, service, and subsystem.

| Section                                      | Description |
|----------------------------------------------|-------------|
| [Binaries](reference/bin/ww.md)              | Main CLI dispatcher (`ww`) and bootstrap (`ww-init.sh`) |
| [Core Libraries](reference/lib/)             | Core utilities and managers (profile-manager, sync, logging, etc.) |
| [Services](reference/services/)              | All service-level documentation |
| [Cross-Cutting](reference/cross-cutting/)    | Sync engine, config loader, error handling, installer |
| [Extensions](reference/extensions/)          | TaskWarrior & TimeWarrior extensions |
| [Taskwarrior Extensions Overview](reference/extensions/taskwarrior/index.md) | Integrations and overviews |
| [Community Extensions List](reference/extensions/taskwarrior/repos/) | Large list of third-party extensions |
| [Source Map](reference/source-map.yaml)      | Maps each doc to its source files |

---

**Tip**: Use the **sidebar** on the left for the complete navigation. Start with **[Why Work Warrior](whyworkwarrior.md)** for the vision.